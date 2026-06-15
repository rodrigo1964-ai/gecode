# Gecode CSP API — Referencia REST para LLM

> Documentación del endpoint REST del solver CSP Gecode con pipeline de 7 etapas.

---

## Descripcion

**Gecode CSP API** es un servidor REST en Go que recibe un problema CSP en formato JSON,
ejecuta un pipeline de validación y resolución de 7 etapas, y devuelve el resultado como
texto plano estructurado.

El servidor llama internamente `bash pipeline.sh <archivo_temporal.json>` y retorna el stdout
combinado de todas las etapas.

---

## Base URL

```
https://gecode-05bi.onrender.com
```

Deploy en Render (Docker). El servidor escucha en el puerto definido por la variable de
entorno `PORT` (default: 8080). CORS habilitado para todos los orígenes (`*`).

---

## Endpoints

### `POST /api/gecode`

Ejecuta el pipeline CSP completo sobre el JSON de entrada.

**Alias:** `POST /solve` (mismo handler)

**Headers:**
```
Content-Type: application/json
```

**Body:** JSON del problema CSP (ver sección "Formato de Entrada JSON").

**Timeout:** 30 segundos. Si el pipeline excede ese límite, el proceso es terminado y
se retorna error 500.

**Respuesta exitosa (200):**
```json
{
  "success": true,
  "results": "══════════════════════════════════════════\n  /tmp/gecode-abc123.json\n══════════════════════════════════════════\n  [1] SyntaxChecker    ok\n  [2] JsonToGraph      ok\n  [3] FunctionChecker  ok\n  [4] FwdConsistency   ok\n  [5] BwdConsistency   ok\n  [6] TestGecodeBridge →\n..."
}
```

El campo `results` es una cadena de texto plano con el output de las 7 etapas.
Si una etapa falla, el pipeline se detiene en esa etapa y `results` incluye el
mensaje de error de la etapa fallida.

**Respuesta de error (400/500):**
```json
{
  "success": false,
  "error": "descripción del error"
}
```

Casos de error:
- `400` — Body no es JSON válido, o error leyendo el cuerpo de la petición
- `405` — Método no permitido (solo se acepta POST)
- `500` — Error al crear archivo temporal, o fallo del pipeline

---

### `GET /health`

Health check del servidor.

**Respuesta (200):**
```json
{
  "status": "ok",
  "service": "Gecode CSP API",
  "timestamp": 1749945600
}
```

`timestamp` es Unix epoch en segundos.

---

## Pipeline CSP — 7 Etapas

El script `pipeline.sh` procesa el archivo JSON de entrada a través de estas etapas
en secuencia. Cada etapa recibe la salida de la anterior. Si una etapa falla, el
pipeline imprime `[N] NombreEtapa FAIL` seguido del error y se detiene.

| Etapa | Binario            | Descripcion                                          |
|-------|--------------------|------------------------------------------------------|
| 1     | `SyntaxChecker`    | Valida la sintaxis del JSON de entrada               |
| 2     | `JsonToGraph`      | Construye grafo AST de las restricciones             |
| 3     | `FunctionChecker`  | Verifica objetos de funciones user-defined           |
| 4     | `FwdConsistency`   | Propagacion hacia adelante (AC-3)                    |
| 5     | `BwdConsistency`   | Proyeccion inversa (arco-consistencia backward)      |
| 6     | `TestGecodeBridge` | Resolucion CSP completa con el motor Gecode          |
| 7     | `VerifyWithBison`  | Verificacion de soluciones con GNUBison (opcional)   |

La etapa 7 solo se activa si el pipeline se invoca con `--verify-bison`. Desde la API
REST no se pasa esa opcion, por lo que normalmente se ejecutan solo las etapas 1-6.

**Ejemplo de salida exitosa en `results`:**
```
══════════════════════════════════════════
  /tmp/gecode-abc123.json
══════════════════════════════════════════
  [1] SyntaxChecker    ok
  [2] JsonToGraph      ok
  [3] FunctionChecker  ok
  [4] FwdConsistency   ok
  [5] BwdConsistency   ok
  [6] TestGecodeBridge →
<salida del solver Gecode con soluciones>
```

**Ejemplo de salida con fallo en etapa 4:**
```
══════════════════════════════════════════
  /tmp/gecode-abc123.json
══════════════════════════════════════════
  [1] SyntaxChecker    ok
  [2] JsonToGraph      ok
  [3] FunctionChecker  ok
  [4] FwdConsistency FAIL
<mensaje de error de FwdConsistency>
```

---

## Formato de Entrada JSON

El body del `POST /api/gecode` debe ser un JSON con la siguiente estructura:

```typescript
{
  description: string;          // Descripcion del problema CSP (libre)
  variables: Variable[];        // Array de variables del problema
  expressions: Expression[];    // Array de restricciones
}
```

### Variable

```typescript
{
  name: string;                 // Nombre en mayusculas (convencion)
  type: "boolean" | "integer" | "numeric" | "set";
  domain: any[];                // Rango valido de valores
  value: any[];                 // Valor(es) actual(es) — puede ser array (incertidumbre)
}
```

**Tipos de variable:**

| Tipo      | domain                          | value                      |
|-----------|---------------------------------|----------------------------|
| `boolean` | `[true, false]`                 | `[true]` o `[false]`       |
| `integer` | lista de enteros: `[0,1,2,3]`   | subset: `[0,1]`            |
| `numeric` | rango `[min, max]`: `[10.0, 40.0]` | valores: `[20.0, 25.0]` |
| `set`     | lista de strings                | subset de strings          |

### Expression

```typescript
{
  constraints: string[];        // Array con una o mas restricciones en texto
}
```

**Sintaxis de restricciones:**

| Operacion         | Ejemplo                                    |
|-------------------|--------------------------------------------|
| Igualdad boolean  | `"VAR = true"`, `"VAR = false"`            |
| AND logico        | `"VAR1 = true AND VAR2 = false"`           |
| Pertenencia set   | `"VAR IN {VALOR1, VALOR2}"`                |
| Rango integer     | `"VAR IN [0, 5]"`                          |
| Rango numeric     | `"VAR IN [10.0, 30.0]"`                    |
| Comparacion       | `"VAR >= 3"`, `"VAR <= 10"`                |
| Aritmetica        | `"VAR1 + VAR2 <= 10"`                      |

---

## Ejemplos

### Ejemplo 1 — Control de Acceso (Booleanos + Set + Integer + Numeric)

```bash
curl -X POST https://gecode-05bi.onrender.com/api/gecode \
  -H "Content-Type: application/json" \
  -d '{
    "description": "Control de acceso a edificio corporativo",
    "variables": [
      { "name": "PUERTA_ABIERTA",  "type": "boolean", "domain": [true, false], "value": [false] },
      { "name": "TARJETA_VALIDA",  "type": "boolean", "domain": [true, false], "value": [true]  },
      { "name": "HORARIO_LABORAL", "type": "boolean", "domain": [true, false], "value": [true]  },
      { "name": "ZONA",            "type": "set",     "domain": ["NORTE","SUR","ESTE","OESTE"], "value": ["NORTE","SUR"] },
      { "name": "INTENTOS",        "type": "integer", "domain": [0,1,2,3,4,5], "value": [0,1] },
      { "name": "TEMPERATURA_C",   "type": "numeric", "domain": [10.0, 40.0],  "value": [20.0, 25.0] }
    ],
    "expressions": [
      { "constraints": ["PUERTA_ABIERTA = false"] },
      { "constraints": ["TARJETA_VALIDA = true AND HORARIO_LABORAL = true"] },
      { "constraints": ["ZONA IN {NORTE, SUR, ESTE}"] },
      { "constraints": ["INTENTOS IN [0, 3]"] },
      { "constraints": ["TEMPERATURA_C IN [18.0, 28.0]"] }
    ]
  }'
```

### Ejemplo 2 — Inventario (multiples restricciones combinadas)

```json
{
  "description": "Gestion de inventario de almacen",
  "variables": [
    { "name": "STOCK_OK",       "type": "boolean", "domain": [true, false],               "value": [true]       },
    { "name": "CATEGORIA",      "type": "set",     "domain": ["CAT_A","CAT_B","CAT_C"],   "value": ["CAT_A"]    },
    { "name": "CANTIDAD",       "type": "integer", "domain": [10,20,50,100,200,500,1000], "value": [100,200,500]},
    { "name": "DIAS_ENTREGA",   "type": "integer", "domain": [1,2,3,5,7,10,15,20,30],    "value": [3,5,7]      },
    { "name": "PRECIO",         "type": "numeric", "domain": [1.0, 1000.0],               "value": [50.0, 150.0]}
  ],
  "expressions": [
    { "constraints": ["STOCK_OK = true"] },
    { "constraints": ["CATEGORIA IN {CAT_A, CAT_B}"] },
    { "constraints": ["CANTIDAD IN [50, 1000]"] },
    { "constraints": ["DIAS_ENTREGA IN [1, 10]"] },
    { "constraints": ["PRECIO IN [10.0, 500.0]"] },
    { "constraints": ["CANTIDAD >= 100 AND DIAS_ENTREGA <= 10"] }
  ]
}
```

### Health check

```bash
curl https://gecode-05bi.onrender.com/health
# → {"status":"ok","service":"Gecode CSP API","timestamp":1749945600}
```

---

## Notas para LLM

- El campo `results` siempre es texto plano, no JSON anidado. Parsear linea por linea.
- Para detectar exito del pipeline: buscar `[6] TestGecodeBridge` en `results`.
- Para detectar fallo: buscar `FAIL` en cualquier linea de `results`.
- Las variables con `value` de mas de un elemento representan incertidumbre (multiples
  valores posibles). El solver evalua todas las combinaciones.
- El campo `domain` define el espacio de busqueda; `value` define el estado actual
  dentro de ese dominio.
- Las restricciones en `expressions[].constraints` usan sintaxis Pascal-like, no SQL.
  Usar `AND` (no `&&`), `IN` para pertenencia, `=` para igualdad (no `==`).

---

**Version:** 1.0
**Fecha:** 2026-06-15
**Propósito:** Referencia REST para integracion con LLM y pipelines automatizados
