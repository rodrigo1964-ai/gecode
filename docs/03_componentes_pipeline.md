---
title: "GeCode CSP Pipeline - Componentes del Pipeline"
subtitle: "Detalle de Cada Componente del Sistema"
author: "Proyecto GeCode CSP Pipeline"
date: "2026"
geometry: margin=2.5cm
fontsize: 11pt
colorlinks: true
---

\newpage

# Componentes del Pipeline

El pipeline de GeCode CSP está compuesto por **9 componentes principales** que transforman y procesan problemas CSP desde la entrada JSON hasta la resolución completa. Cada componente tiene una responsabilidad específica y bien definida.

## Flujo General

```
JSON Input
    ↓
[1] SyntaxChecker     → Validación de sintaxis y semántica
    ↓
[2] JsonToGraph       → Construcción de AST y grafo
    ↓
[3] FunctionChecker   → Verificación de funciones
    ↓
[4] FwdConsistency    → Propagación forward (AC-3)
    ↓
[5] BwdConsistency    → Propagación backward (HC4)
    ↓
[6] CSPEval           → Evaluación rápida
    ↓
[7] ForwardChain      → Encadenamiento iterativo
    ↓
[8] TestGecodeBridge  → Resolución con Gecode
    ↓
Solutions Output

Persistencia:
[9] JsonSink/JsonSource → SQLite storage
```

\newpage

# 1. SyntaxChecker

## Propósito

Validar la **sintaxis y coherencia semántica** de un archivo JSON de sistema CSP antes de procesarlo con el pipeline. Actúa como el primer filtro de calidad para detectar errores tempranos.

## Entrada/Salida

**Entrada**: Archivo JSON con campos `variables`, `expressions`, `functions`.

**Salida**: JSON con resultado de validación:
```json
{
  "status": "ok"
}
```

O en caso de errores:
```json
{
  "status": "error",
  "errors": [
    {
      "rule": "nombre_regla",
      "msg": "descripción del error"
    }
  ]
}
```

## Reglas de Validación

El SyntaxChecker verifica las siguientes reglas:

1. **Campos obligatorios presentes**: `variables`, `expressions`
2. **Variables referenciadas existen**: Todas las variables usadas en constraints están declaradas
3. **Funciones usadas están declaradas**: Referencias a funciones resuelven correctamente
4. **Referencias válidas**: Variables y funciones se resuelven sin ambigüedades
5. **Sintaxis parseable**: Cada constraint tiene sintaxis válida
6. **Coherencia de dominios**: El campo `value` es subconjunto del `domain`
7. **Aridad correcta**: Funciones user-defined tienen el número correcto de parámetros
8. **No sobrescritura**: No se sobreescriben built-ins del motor (`abs`, `dist`, etc.)

## Códigos de Salida

- `0` = validación exitosa
- `1` = errores de validación encontrados

## Uso

```bash
# Validar archivo
./bin/SyntaxChecker sistema.json

# En el pipeline
./bin/SyntaxChecker sistema.json && ./bin/JsonToGraph sistema.json | ...
```

## Ejemplo

```bash
$ ./bin/SyntaxChecker ejemplos/Json_input_1.json
{
  "status": "ok"
}

$ echo $?
0
```

## Tecnologías

- **Pascal** + **MiniJSON** para parsing JSON
- Validación semántica custom

## Posición en el Pipeline

**ETAPA 1** — Siempre primera antes de JsonToGraph.

\newpage

# 2. JsonToGraph

## Propósito

Convierte un JSON de sistema CSP en un **grafo de restricciones con AST**. Es la etapa central que transforma expresiones de texto en una estructura de datos procesable por el resto del pipeline.

## Entrada/Salida

**Entrada**: Archivo JSON con `variables`, `expressions`, `functions`.

**Salida**: JSON con cuatro secciones:
- `variables` — variables con id asignado, tipo y dominio
- `functions` — funciones user-defined declaradas
- `constraints` — cada constraint con su AST (nodos tipados) y referencias a variables/funciones usadas
- `adjacency` — índice inverso: qué constraints afectan a cada variable

## Algoritmo Principal

Utiliza un **Pratt Parser** para construir el árbol de sintaxis abstracta de cada expresión:

1. **Tokenización**: Divide la expresión en tokens
2. **Parsing por precedencia**: Construye AST respetando precedencia de operadores
3. **Construcción de grafo**: Genera nodos y aristas del grafo de dependencias
4. **Indexación**: Crea índice inverso de qué constraints afectan a cada variable

## Tipos de Nodo AST

El parser genera los siguientes tipos de nodos:

### Nodos de Valor
- `Variable` — referencia a variable
- `Number` — literal numérico
- `Set` — conjunto literal
- `Interval` — intervalo [a, b]

### Nodos Relacionales
- `Equals` — operador `=`
- `NotEquals` — operador `<>`
- `Less` — operador `<`
- `Greater` — operador `>`
- `LessEq` — operador `<=`
- `GreaterEq` — operador `>=`

### Nodos Lógicos
- `And` — operador `AND`
- `Or` — operador `OR`
- `Not` — operador `NOT`

### Nodos Aritméticos
- `Add` — operador `+`
- `Subtract` — operador `-`
- `Multiply` — operador `*`
- `Divide` — operador `/`
- `Negate` — negación unaria

### Nodos Especiales
- `FunctionCall` — llamada a función
- `In` — operador de pertenencia `IN`

## Uso

```bash
# Salida a stdout
./bin/JsonToGraph sistema.json

# Salida a archivo
./bin/JsonToGraph sistema.json salida.json

# En el pipeline
./bin/JsonToGraph sistema.json | ./bin/FwdConsistency
```

## Ejemplo de Transformación

**Entrada**:
```json
{
  "variables": [
    {"nombre": "x", "tipo": "integer", "domain": [1, 10]}
  ],
  "expresiones": ["x + y * 2"]
}
```

**Salida (AST)**:
```json
{
  "ast": {
    "tipo": "BINOP",
    "op": "+",
    "izq": {"tipo": "IDENT", "nombre": "x"},
    "der": {
      "tipo": "BINOP",
      "op": "*",
      "izq": {"tipo": "IDENT", "nombre": "y"},
      "der": {"tipo": "LITERAL", "valor": 2}
    }
  }
}
```

## Tecnologías

- **Pascal** + **PrattParser** + **ExpressionAST**
- Parsing por precedencia de operadores
- Construcción de grafo dirigido acíclico

## Posición en el Pipeline

**ETAPA 2** — Después de SyntaxChecker, antes de todo lo demás.

\newpage

# 3. FunctionChecker

## Propósito

Verifica que los **archivos objeto** (.so / .o) de las funciones user-defined referenciadas en el grafo existan en los directorios de búsqueda antes de intentar ejecutar el pipeline.

## Entrada/Salida

**Entrada**: JSON de grafo (salida de JsonToGraph).

**Salida**: JSON con resultado:
```json
{
  "status": "ok"|"missing"|"error",
  "checked": N,
  "found": N,
  "missing": N,
  "functions": [
    {
      "name": "miFuncion",
      "object": "func_miFuncion.so",
      "path": "./lib/func_miFuncion.so",
      "found": true
    }
  ]
}
```

## Algoritmo de Búsqueda

1. **Extraer funciones**: Lee la sección `functions` del grafo JSON
2. **Buscar objetos**: Para cada función, busca `func_<nombre>.so` o `func_<nombre>.o` en:
   - `.` (directorio actual)
   - `./lib`
   - `./obj`
   - `/usr/local/lib/csp`
   - Directorios adicionales con `--path`
3. **Reportar resultados**: Marca cada función como encontrada o faltante

## Directorios de Búsqueda

Por defecto: `.:./lib:./obj:/usr/local/lib/csp`

Puede personalizarse:
```bash
./bin/FunctionChecker grafo.json --path ./lib:./obj:/usr/local/lib/csp
```

## Códigos de Salida

- `0` = todos los objetos encontrados
- `1` = algún objeto faltante (puede continuar con advertencia)
- `2` = error fatal (no se puede continuar)

## Uso

```bash
# Verificación básica
./bin/FunctionChecker grafo.json

# Con directorios personalizados
./bin/FunctionChecker grafo.json --path ./custom_libs:./obj

# En el pipeline
./bin/JsonToGraph sistema.json | ./bin/FunctionChecker
```

## Notas

- Solo relevante si el sistema usa funciones user-defined
- Si no hay funciones, el resultado es siempre "ok"
- Los objetos no se cargan, solo se verifica su existencia

## Tecnologías

- **Pascal** + **UCSPJson**
- Búsqueda de archivos en filesystem

## Posición en el Pipeline

**ETAPA 3** — Después de JsonToGraph, antes de FwdConsistency.

\newpage

# 4. FwdConsistency

## Propósito

Aplica **consistencia de arco hacia adelante (AC-3)** al grafo de restricciones. Propaga cada constraint desde las variables conocidas hacia las desconocidas, reduciendo dominios progresivamente.

## Entrada/Salida

**Entrada**: JSON de grafo (salida de JsonToGraph).

**Salida**: JSON con:
- `status` — "arc_consistent" | "inconsistent"
- `queue_ops` — operaciones de cola AC-3
- `firings` — reglas disparadas
- `steps` — array de pasos con cada reducción de dominio
- `variables` — dominios finales de todas las variables

## Algoritmo AC-3

**Arc Consistency Algorithm 3** (AC-3):

```
1. Inicializar cola Q con todos los arcos (X, C) donde X es variable,
   C es constraint que involucra a X
2. Mientras Q no esté vacía:
   a. Extraer arco (X, C) de Q
   b. Si Revise(X, C) reduce el dominio de X:
      - Si domain(X) está vacío → INCONSISTENT
      - Agregar a Q todos los arcos (Y, C') donde Y depende de X
3. Si ningún dominio quedó vacío → ARC_CONSISTENT
```

**Revise(X, C)**:
```
Para cada valor v en domain(X):
  Evaluar constraint C con X=v
  Si C no se puede satisfacer con ningún valor de otras variables:
    Eliminar v de domain(X)
Retornar true si algún valor fue eliminado
```

## Ejemplo de Paso

```json
{
  "steps": [
    {
      "var": "X",
      "constraint": "X > 5",
      "before": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      "after": [6, 7, 8, 9, 10]
    }
  ]
}
```

## Uso

```bash
# Salida a stdout
./bin/FwdConsistency grafo.json

# Salida a archivo
./bin/FwdConsistency grafo.json salida.json

# Con persistencia
./bin/FwdConsistency grafo.json | ./bin/JsonSink runs.db fwd
```

## Tecnologías

- **Pascal** + **MiniMath** + **AC-3 Algorithm**
- Evaluación de restricciones con aritmética de intervalos

## Posición en el Pipeline

**ETAPA 4** — Después de FunctionChecker.
Complementa a BwdConsistency: ambos se aplican al mismo grafo.

\newpage

# 5. BwdConsistency

## Propósito

Aplica **consistencia de arco hacia atrás (HC4-revise)** al grafo de restricciones. Para constraints del tipo `V = f(W)`, invierte `f` para restringir `W` en función del dominio reducido de `V`. Complementa a FwdConsistency.

## Entrada/Salida

**Entrada**: JSON de grafo (salida de JsonToGraph).

**Salida**: JSON con la misma estructura que FwdConsistency:
- `status` — "arc_consistent" | "inconsistent"
- `queue_ops` — operaciones de cola
- `firings` — reglas disparadas
- `steps` — reducciones de dominio (marcadas con "(bwd)")
- `variables` — dominios finales

## Algoritmo HC4-Revise

**Hull Consistency 4** (HC4) con proyección inversa:

```
Para cada constraint V = f(X, Y, Z):
1. Forward: Calcular domain(V) = f(domain(X), domain(Y), domain(Z))
2. Backward: Para cada operando (ej. X):
   a. Proyectar constraint: X = f_inv(V, Y, Z)
   b. Calcular domain_nuevo(X) = f_inv(domain(V), domain(Y), domain(Z))
   c. Intersectar: domain(X) ← domain(X) ∩ domain_nuevo(X)
3. Iterar hasta punto fijo
```

## Diferencia con FwdConsistency

| Aspecto | FwdConsistency | BwdConsistency |
|---------|----------------|----------------|
| Dirección | Izquierda → Derecha | Derecha → Izquierda |
| Algoritmo | AC-3 (Arc Consistency) | HC4 (Hull Consistency) |
| Estrategia | Evaluar constraint con valores | Proyectar función inversa |
| Ejemplo | `x + y = 10` → reducir `y` dado `x` | `z = x + y` → reducir `x, y` dado `z` |

Juntos cubren **más reducciones de dominio** que cada uno por separado.

## Ejemplo

**Constraint**: `z = x + y`

**Forward**:
```
x ∈ [1, 5], y ∈ [2, 8]
→ z ∈ [1+2, 5+8] = [3, 13]
```

**Backward**:
```
z ∈ [5, 10]  (dominio reducido por otra restricción)
→ x ∈ [5-8, 10-2] ∩ [1, 5] = [-3, 8] ∩ [1, 5] = [1, 5]  (sin cambio)
→ y ∈ [5-5, 10-1] ∩ [2, 8] = [0, 9] ∩ [2, 8] = [2, 8]   (sin cambio)
```

## Uso

```bash
# Salida a stdout
./bin/BwdConsistency grafo.json

# En paralelo con FwdConsistency
./bin/FwdConsistency grafo.json | ./bin/BwdConsistency

# Con persistencia
./bin/BwdConsistency grafo.json | ./bin/JsonSink runs.db bwd
```

## Tecnologías

- **Pascal** + **MiniMath** + **Interval Analysis**
- Aritmética de intervalos con proyección inversa

## Posición en el Pipeline

**ETAPA 5** — En paralelo o secuencia con FwdConsistency.

\newpage

# 6. CSPEval

## Propósito

**Evaluador CSP genérico** con propagación iterativa de dominios. Maneja los cuatro tipos de variable del motor (numeric, integer, boolean, set) con operaciones de reducción apropiadas para cada tipo.

## Entrada/Salida

**Entrada**: JSON de grafo (salida de JsonToGraph).

**Salida**: JSON con:
- `status` — "ok" | "solved" | "contradiction"
- `iterations` — iteraciones hasta punto fijo (máx 200)
- `variables` — dominios finales con flags

## Tipos de Variable Soportados

| Tipo | Dominio | Operaciones |
|------|---------|-------------|
| `numeric` | Intervalo [lo, hi] | Aritmética de punto flotante |
| `integer` | Enumerado de enteros | Operaciones discretas |
| `boolean` | {false, true} | Lógica booleana |
| `set` | Enumerado de etiquetas | Operaciones de conjuntos |

## Algoritmo de Propagación

```
1. Inicializar dominios de todas las variables
2. Repetir hasta punto fijo (max 200 iteraciones):
   a. Para cada constraint:
      - Evaluar con dominios actuales
      - Calcular nuevo dominio resultante
      - Intersectar con dominio actual
   b. Si algún dominio quedó vacío → CONTRADICTION
   c. Si todos los dominios tienen 1 solo valor → SOLVED
   d. Si ningún dominio cambió → PUNTO FIJO (status: ok)
3. Retornar dominios finales
```

## Ejemplo de Salida

```json
{
  "status": "ok",
  "iterations": 5,
  "variables": [
    {
      "name": "X",
      "type": "integer",
      "domain": [6, 7, 8, 9, 10],
      "solved": false,
      "empty": false
    },
    {
      "name": "Y",
      "type": "integer",
      "domain": [5],
      "solved": true,
      "empty": false
    }
  ]
}
```

## Diferencia con FwdConsistency/ForwardChain

| Aspecto | CSPEval | FwdConsistency | ForwardChain |
|---------|---------|----------------|--------------|
| Trazado | No genera `steps` | Genera `steps` detallados | Genera `steps` por iteración |
| Velocidad | Más rápido | Medio | Más lento |
| Uso | Evaluación rápida | Debugging/análisis | Debugging/inferencia |

CSPEval produce **solo el resultado final** de dominios, sin trazar los pasos intermedios.

## Uso

```bash
# Evaluación rápida
./bin/CSPEval grafo.json

# Con persistencia
./bin/CSPEval grafo.json | ./bin/JsonSink runs.db cspeval
```

## Tecnologías

- **Pascal** + **MiniMath** + **Multi-domain evaluation**
- Propagación iterativa hasta punto fijo

## Posición en el Pipeline

Etapa de **evaluación rápida** antes de pasar a TestGecodeBridge.

\newpage

# 7. ForwardChain

## Propósito

**Encadenamiento hacia adelante iterativo**: aplica propagación de constraints en múltiples pasadas hasta alcanzar un punto fijo (ningún dominio cambia) o detectar una contradicción (dominio vacío).

## Entrada/Salida

**Entrada**: JSON de grafo (salida de JsonToGraph).

**Salida**: JSON con:
- `status` — "ok" | "solved" | "contradiction"
- `iterations` — número de pasadas realizadas
- `steps` — array de pasos por iteración
- `variables` — dominios finales

## Algoritmo de Encadenamiento

```
iteration = 1
REPEAT:
  changed = false
  FOR EACH constraint C:
    FOR EACH variable V in C:
      domain_old = domain(V)
      domain_new = evaluate_constraint(C, V)
      domain(V) = domain_old ∩ domain_new
      IF domain(V) != domain_old:
        Log step: {iteration, V, domain_old, domain_new}
        changed = true
      IF domain(V) is empty:
        RETURN "contradiction"
  iteration++
UNTIL NOT changed OR iteration > max_iterations

IF all variables have single value:
  RETURN "solved"
ELSE:
  RETURN "ok"
```

## Estados de Retorno

- **"solved"** — todas las variables tienen exactamente un valor
- **"contradiction"** — algún dominio quedó vacío (sistema inconsistente)
- **"ok"** — reducción parcial alcanzó punto fijo

## Ejemplo de Steps

```json
{
  "steps": [
    {
      "iteration": 1,
      "var": "X",
      "before": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      "after": [6, 7, 8, 9, 10]
    },
    {
      "iteration": 2,
      "var": "Y",
      "before": [1, 2, 3, 4, 5],
      "after": [1, 2, 3, 4]
    }
  ]
}
```

## Diferencia con FwdConsistency

| Aspecto | FwdConsistency | ForwardChain |
|---------|----------------|--------------|
| Estrategia | AC-3 con cola | Múltiples pasadas completas |
| Eficiencia | Más eficiente | Más simple |
| Uso | Producción | Trazado/debugging |
| Output | Steps ordenados por cola | Steps ordenados por iteración |

FwdConsistency aplica **AC-3 una sola vez con cola**.
ForwardChain hace **múltiples pasadas completas** sobre todos los constraints hasta punto fijo.

## Uso

```bash
# Encadenamiento con trazado
./bin/ForwardChain grafo.json

# Con persistencia
./bin/ForwardChain grafo.json | ./bin/JsonSink runs.db forward
```

## Tecnologías

- **Pascal** + **MiniMath**
- Evaluación iterativa con punto fijo

## Posición en el Pipeline

**Alternativa a FwdConsistency** para sistemas con muchas iteraciones o cuando se requiere trazado detallado.

\newpage

# 8. JsonSink

## Propósito

**Sumidero del pipeline**: lee JSON de stdin y lo persiste en una base de datos SQLite, devolviendo por stdout un JSON de confirmación encadenable.

## Entrada/Salida

**Entrada**: JSON producido por cualquier etapa del pipeline (stdin).

**Salida**: JSON de confirmación:
```json
{
  "ok": true,
  "id": 42,
  "tag": "fwd",
  "status": "arc_consistent"
}
```

## Esquema SQLite

```sql
CREATE TABLE runs (
  id      INTEGER PRIMARY KEY AUTOINCREMENT,
  ts      TEXT,    -- timestamp ISO-8601 automático
  tag     TEXT,    -- etiqueta de la etapa
  status  TEXT,    -- campo "status" extraído del JSON
  payload TEXT     -- JSON completo de la etapa
);
```

## Funcionalidad

1. **Leer JSON** de stdin
2. **Extraer status** automáticamente del JSON
3. **Insertar registro** en tabla `runs` con:
   - timestamp automático
   - tag (argumento 2)
   - status extraído
   - payload completo
4. **Emitir confirmación** por stdout (encadenable)

## Uso

```bash
# Almacenar JSON
echo '{"data": "value"}' | ./bin/JsonSink db.sqlite mi_tag

# Pipeline con persistencia
./bin/FwdConsistency grafo.json | ./bin/JsonSink pipeline.db fwd

# Cadena completa
./bin/JsonToGraph input.json | ./bin/JsonSink db.sqlite graph | ./bin/FwdConsistency
```

## Notas

- El campo **"status"** se extrae automáticamente del JSON de entrada
- El **payload completo** se almacena para replay o auditoría
- Usa binding de **SQLite3** vía cdecl; no requiere runtime adicional
- Para leer los datos persistidos, usar **JsonSource**

## Tecnologías

- **Pascal** + **SQLite3 bindings**
- Inserción transaccional

## Posición en el Pipeline

**Cierre de cualquier etapa** cuando se desea persistencia.

\newpage

# 9. JsonSource

## Propósito

**Fuente del pipeline**: recupera un JSON persistido en SQLite y lo emite por stdout para continuar el pipeline desde un punto guardado.

## Entrada/Salida

**Entrada**: Base de datos SQLite + filtros opcionales.

**Salida**: El payload JSON original del registro recuperado (stdout).

## Modos de Recuperación

```bash
# Último registro insertado
./bin/JsonSource runs.db

# Último registro con tag "fwd"
./bin/JsonSource runs.db fwd

# Registro con id=42 y tag="fwd"
./bin/JsonSource runs.db fwd 42
```

## Casos de Uso Típicos

### 1. Guardar y Reutilizar Grafo

```bash
# Guardar grafo
./bin/JsonToGraph sistema.json | ./bin/JsonSink pipeline.db graph

# Correr FwdConsistency y BwdConsistency desde el mismo grafo
./bin/JsonSource pipeline.db graph | ./bin/FwdConsistency | ./bin/JsonSink pipeline.db fwd
./bin/JsonSource pipeline.db graph | ./bin/BwdConsistency | ./bin/JsonSink pipeline.db bwd
```

### 2. Resolver CSP desde Grafo Guardado

```bash
# Resolver desde grafo persistido
./bin/JsonSource pipeline.db graph | ./bin/TestGecodeBridge
```

### 3. Recuperar Resultado Anterior

```bash
# Analizar resultado de etapa anterior
./bin/JsonSource pipeline.db csp 17 | python3 analizar.py
```

## Notas

- Si no existe el tag o id, termina con **error en stderr** y **exit 1**
- Usa la misma binding mínima de SQLite3 que JsonSink
- Permite **replay** y **debug** de cualquier etapa

## Tecnologías

- **Pascal** + **SQLite3 bindings**
- Query transaccional

## Posición en el Pipeline

**Inicio de cualquier etapa** cuando el input viene de SQLite.
Complemento de JsonSink — juntos implementan **memoria persistente**.

\newpage

# Resumen de Componentes

## Tabla Comparativa

| Componente | Tipo | Entrada | Salida | Propósito Principal |
|------------|------|---------|--------|---------------------|
| SyntaxChecker | Validación | JSON raw | JSON validado | Verificar sintaxis y semántica |
| JsonToGraph | Transformación | JSON validado | Grafo + AST | Construir estructura procesable |
| FunctionChecker | Verificación | Grafo JSON | Reporte | Verificar objetos de funciones |
| FwdConsistency | Propagación | Grafo JSON | Grafo + dominios | AC-3 forward |
| BwdConsistency | Propagación | Grafo JSON | Grafo + dominios | HC4 backward |
| CSPEval | Evaluación | Grafo JSON | Dominios finales | Evaluación rápida |
| ForwardChain | Propagación | Grafo JSON | Grafo + steps | Encadenamiento iterativo |
| JsonSink | Persistencia | JSON (stdin) | Confirmación | Almacenar en SQLite |
| JsonSource | Persistencia | SQLite + filtros | JSON (stdout) | Recuperar desde SQLite |

## Pipelines Típicos

### Pipeline Completo con Propagación

```bash
./bin/SyntaxChecker input.json && \
./bin/JsonToGraph input.json | \
./bin/FunctionChecker | \
./bin/FwdConsistency | \
./bin/BwdConsistency | \
./bin/TestGecodeBridge
```

### Pipeline con Persistencia

```bash
./bin/JsonToGraph input.json | ./bin/JsonSink db.sqlite graph
./bin/JsonSource db.sqlite graph | ./bin/FwdConsistency | ./bin/JsonSink db.sqlite fwd
./bin/JsonSource db.sqlite fwd | ./bin/TestGecodeBridge | ./bin/JsonSink db.sqlite csp
```

### Pipeline de Evaluación Rápida

```bash
./bin/SyntaxChecker input.json && \
./bin/JsonToGraph input.json | \
./bin/CSPEval | \
./bin/TestGecodeBridge
```

---

**Próximo**: Leer **04_integracion_gecode.md** para entender el puente Pascal/C++/Gecode.
