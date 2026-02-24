---
title: "GeCode CSP Pipeline - Introducción"
subtitle: "Sistema de Procesamiento de Problemas de Constraint Programming"
author: "Proyecto GeCode CSP Pipeline"
date: "2026"
geometry: margin=2.5cm
fontsize: 11pt
colorlinks: true
---

\newpage

# Introducción

## ¿Qué es GeCode CSP Pipeline?

**GeCode CSP Pipeline** es un sistema completo de procesamiento para problemas de **Constraint Satisfaction Problems (CSP)** que integra herramientas de validación, análisis y resolución mediante Gecode.

El pipeline procesa problemas definidos en formato JSON, pasando por múltiples etapas de verificación y optimización, hasta obtener soluciones completas usando el solver Gecode.

## Propósito del Proyecto

Este sistema fue diseñado para:

1. **Validar** especificaciones de problemas CSP en formato JSON
2. **Analizar** y transformar expresiones en grafos AST
3. **Verificar** la consistencia de restricciones
4. **Propagar** restricciones usando algoritmos como AC-3
5. **Resolver** problemas CSP completos con Gecode
6. **Persistir** resultados intermedios opcionalmente en SQLite

## Características Principales

### ✅ Validación y Análisis

- **SyntaxChecker**: Validación robusta de sintaxis JSON
- **JsonToGraph**: Construcción de AST y grafos de restricciones
- **FunctionChecker**: Verificación de funciones definidas por el usuario

### ✅ Propagación de Restricciones

- **FwdConsistency**: Implementación del algoritmo AC-3 (Arc Consistency)
- **BwdConsistency**: Análisis de intervalos y proyección inversa
- **ForwardChain**: Encadenamiento hacia adelante para inferencia lógica

### ✅ Resolución CSP

- **TestGecodeBridge**: Puente a Gecode para resolución completa
- **Soporte de 4 tipos**: integer, float, logic, set
- **Múltiples soluciones**: Búsqueda exhaustiva o primera solución

### ✅ Persistencia y Utilidades

- **JsonSink**: Almacenamiento en SQLite
- **JsonSource**: Recuperación desde SQLite
- **CSPEval**: Evaluador de expresiones

### ✅ Compilación Flexible

- **Pipeline tools**: Compilación sin Gecode
- **Monolítica**: Ejecutables standalone de ~8-12 MB
- **Estática/Dinámica**: Soporte para linkeo estático o dinámico de Gecode

## Tipos de Datos Soportados

| Tipo    | Descripción                  | Formato JSON                          |
|---------|------------------------------|---------------------------------------|
| integer | Números enteros              | `{"domain": [1, 100], "value": 10}`  |
| float   | Números de punto flotante    | `{"domain": [0.0, 50.0], "value": 15.5}` |
| logic   | Valores booleanos            | `{"domain": [true, false], "value": true}` |
| set     | Conjuntos de valores         | `{"domain": {"miembros": ["A", "B"]}, "value": "A"}` |

## Operadores Soportados

### Aritméticos
- `+` Suma
- `-` Resta
- `*` Multiplicación
- `/` División

### Lógicos
- `AND` Conjunción lógica
- `OR` Disyunción lógica
- `NOT` Negación
- `IMPLICA` Implicación

### Relacionales
- `=` Igualdad
- `<>` Desigualdad
- `<` Menor que
- `>` Mayor que
- `<=` Menor o igual
- `>=` Mayor o igual

### Conjuntos
- `UNION` Unión de conjuntos
- `INTERSECT` Intersección
- `DIFFERENCE` Diferencia
- `SUBSET` Subconjunto
- `CARDINALITY` Número de elementos
- `IN` Pertenencia

## Funciones Matemáticas

El sistema incluye la biblioteca **MiniMath** con funciones:

- `abs(x)` - Valor absoluto
- `sqrt(x)` - Raíz cuadrada
- `sqr(x)` - Cuadrado
- `sin(x)`, `cos(x)`, `tan(x)` - Funciones trigonométricas
- `ln(x)` - Logaritmo natural
- `exp(x)` - Exponencial
- `pow(x, y)` - Potencia

\newpage

# Compilación e Instalación

## Requisitos del Sistema

### Para Herramientas del Pipeline

- **Free Pascal Compiler** (fpc) >= 3.0
- **gcc** >= 7.0
- **make**
- **SQLite3** (libsqlite3-dev)

### Para Integración con Gecode

- **g++** >= 7.0
- **Gecode** 6.x (estático o dinámico)
- **Free Pascal Compiler** (fpc) >= 3.0

## Instalación de Dependencias

### Ubuntu/Debian

```bash
# Herramientas básicas
sudo apt install build-essential fpc gcc make libsqlite3-dev

# Para Gecode (versión dinámica del sistema)
sudo apt install libgecode-dev

# Para compilar PDFs (opcional)
sudo apt install pandoc texlive-latex-base texlive-fonts-recommended texlive-latex-extra
```

### Fedora/RHEL

```bash
# Herramientas básicas
sudo dnf install gcc fpc make sqlite-devel

# Para compilar PDFs (opcional)
sudo dnf install pandoc texlive-scheme-basic
```

## Instalación de Gecode Estático

Para crear ejecutables verdaderamente standalone, se recomienda compilar Gecode estático:

```bash
cd /tmp
wget https://github.com/Gecode/gecode/archive/refs/tags/release-6.3.0.tar.gz
tar xzf release-6.3.0.tar.gz
cd gecode-release-6.3.0

./configure \
    --prefix=$HOME/gecode-static \
    --disable-shared \
    --enable-static \
    --disable-examples \
    --disable-qt \
    --disable-gist

make -j$(nproc)
make install

# Configurar variable de entorno
export GECODE_HOME=$HOME/gecode-static
echo "export GECODE_HOME=$HOME/gecode-static" >> ~/.bashrc
```

## Compilación del Proyecto

### Compilación Completa

```bash
# Clonar o descargar el proyecto
cd gecode

# Compilar todo (pipeline + gecode)
make

# Verificar ejecutables generados
ls -lh bin/
```

### Compilación Selectiva

```bash
# Solo herramientas del pipeline (sin Gecode)
make pipeline

# Solo herramientas Gecode
make gecode

# Limpieza
make clean       # Solo objetos
make distclean   # Todo
```

### Compilación Monolítica

Para crear ejecutables totalmente standalone:

```bash
./scripts/build_monolithic.sh src/TestGecodeBridge.pas
```

Esto genera un ejecutable que incluye:

- ✅ Todo el código Pascal compilado
- ✅ Puente C++ a Gecode
- ✅ Gecode linkeado estáticamente
- ✅ Sin dependencias de libgecode*.so
- ✅ Tamaño: ~8-12 MB

## Verificación de la Instalación

```bash
# Probar herramientas del pipeline
./bin/SyntaxChecker ejemplos/Json_input_1.json
./bin/JsonToGraph ejemplos/Json_input_1.json
./bin/FwdConsistency graph.json

# Probar integración Gecode
./bin/TestGecodeBridge graph.json

# Ejecutar pipeline completo
./scripts/pipeline.sh ejemplos/Json_input_1.json
```

Si todos los comandos ejecutan sin errores, la instalación fue exitosa.

\newpage

# Inicio Rápido

## Ejemplo Básico

### 1. Crear un archivo JSON de entrada

Crear `mi_problema.json`:

```json
{
  "precision": 2,
  "variables": [
    {
      "nombre": "x",
      "tipo": "integer",
      "domain": [1, 10],
      "value": null
    },
    {
      "nombre": "y",
      "tipo": "integer",
      "domain": [1, 10],
      "value": null
    }
  ],
  "expresiones": [
    "x + y = 10",
    "x > y"
  ]
}
```

### 2. Ejecutar el pipeline

```bash
./scripts/pipeline.sh mi_problema.json
```

### 3. Revisar resultados

El pipeline ejecutará todas las etapas y mostrará:

- ✅ Validación de sintaxis
- ✅ Construcción de AST
- ✅ Verificación de funciones
- ✅ Propagación de restricciones
- ✅ Soluciones encontradas por Gecode

## Pipeline con Persistencia

```bash
# Persistir cada etapa en SQLite
./scripts/pipeline.sh --db resultados.db --tag prueba_1 mi_problema.json

# Procesar múltiples archivos
./scripts/pipeline.sh --db resultados.db ejemplos/*.json

# Recuperar resultados de una etapa
./bin/JsonSource resultados.db prueba_1_syntax
./bin/JsonSource resultados.db prueba_1_graph
./bin/JsonSource resultados.db prueba_1_csp
```

## Uso Individual de Componentes

```bash
# 1. Validar sintaxis
./bin/SyntaxChecker ejemplos/Json_input_1.json

# 2. Construir grafo AST
./bin/JsonToGraph ejemplos/Json_input_1.json > graph.json

# 3. Verificar funciones
./bin/FunctionChecker graph.json > graph_checked.json

# 4. Propagación forward
./bin/FwdConsistency graph_checked.json > graph_fwd.json

# 5. Propagación backward
./bin/BwdConsistency graph_fwd.json > graph_bwd.json

# 6. Resolución con Gecode
./bin/TestGecodeBridge graph_bwd.json > solucion.json
```

## Explorar Ejemplos

El directorio `ejemplos/` contiene múltiples archivos de prueba:

```bash
# Listar ejemplos disponibles
ls -1 ejemplos/Json_input_*.json

# Ver contenido de un ejemplo
cat ejemplos/Json_input_1.json

# Ejecutar un ejemplo
./scripts/pipeline.sh ejemplos/Json_input_2.json

# Ejecutar todos los ejemplos
for f in ejemplos/Json_input_*.json; do
    echo "=== Procesando $f ==="
    ./scripts/pipeline.sh "$f"
    echo
done
```

## Próximos Pasos

1. Leer **02_arquitectura.md** para entender el diseño del sistema
2. Leer **03_componentes_pipeline.md** para detalles de cada componente
3. Leer **04_integracion_gecode.md** para entender el puente a Gecode
4. Revisar los reportes de pruebas en `docs/reporte_*.md`

---

**Nota**: Esta es la versión inicial del manual. Para información detallada sobre cada componente, consultar los documentos específicos en `docs/`.
