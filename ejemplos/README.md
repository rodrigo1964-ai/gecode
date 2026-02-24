# Ejemplos de Entrada y Salida

Este directorio contiene archivos JSON de ejemplo para probar el pipeline CSP.

## Estructura de Archivos

- `Json_input_*.json` - Archivos de entrada con definiciones de CSP
- `Json_output_*.json` - Salidas esperadas del pipeline

## Lista de Ejemplos

### Json_input_1.json / Json_output_1.json
Ejemplo básico con variables enteras y restricciones simples.

### Json_input_2.json / Json_output_2.json
Ejemplo con variables float y operaciones aritméticas.

### Json_input_3.json / Json_output_3.json
Ejemplo con variables lógicas y expresiones booleanas.

### Json_input_4.json / Json_output_4.json
Ejemplo con operaciones de conjuntos (sets).

### Json_input_5.json / Json_output_5.json
Ejemplo combinado con múltiples tipos de variables y restricciones.

## Uso

Para ejecutar un ejemplo individual:

```bash
# Ejecutar el pipeline completo
../scripts/pipeline.sh Json_input_1.json

# Solo validar sintaxis
../bin/SyntaxChecker Json_input_1.json

# Construir grafo AST
../bin/JsonToGraph Json_input_1.json

# Resolver con Gecode (requiere grafo previamente generado)
../bin/JsonToGraph Json_input_1.json | ../bin/TestGecodeBridge /dev/stdin
```

Para ejecutar todos los ejemplos:

```bash
# Ejecutar todos con persistencia en SQLite
../scripts/pipeline.sh --db runs.db Json_input_*.json
```

## Formato de Entrada

Cada archivo `Json_input_*.json` sigue este formato:

```json
{
  "precision": <decimales>,
  "variables": [
    {
      "nombre": "<nombre_var>",
      "tipo": "integer|float|logic|set",
      "domain": [<min>, <max>] | {"nombre": "<nombre_set>", "miembros": [...]},
      "value": <valor_inicial>
    }
  ],
  "expresiones": [
    "<expresion_1>",
    "<expresion_2>",
    ...
  ]
}
```

## Formato de Salida

Los archivos `Json_output_*.json` contienen los resultados del procesamiento:

```json
{
  "status": "success|error",
  "variables": [...],
  "constraints": [...],
  "solutions": [...]
}
```

## Agregar Nuevos Ejemplos

Para agregar un nuevo ejemplo:

1. Crear `Json_input_N.json` con la definición del CSP
2. Ejecutar el pipeline: `../scripts/pipeline.sh Json_input_N.json`
3. Verificar la salida y guardarla como `Json_output_N.json`
4. Actualizar este README con la descripción del ejemplo
