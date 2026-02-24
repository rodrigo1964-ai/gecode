================================================================================
gecode
================================================================================

DESCRIPCIÓN
-----------

GeCode CSP Pipeline

Sistema completo de procesamiento de problemas de Programación con Restricciones (Constraint Satisfaction Problems - CSP) con integración de Gecode.

Descripción

Este proyecto implementa un pipeline completo de verificación y resolución de CSP que:

- ✅ Valida sintaxis de archivos JSON de entrada
- ✅ Construye grafos AST (Árbol de Sintaxis Abstracta) de restricciones
- ✅ Verifica funciones definidas por el usuario
- ✅ Realiza propagación de restricciones (forward/backward consistency)
- ✅ Resuelve CSP completos usando Gecode
- ✅ Verifica soluciones con GNUBison (validación cruzada opcional)
- ✅ Soporta 4 tipos de variables: integer, float, logic, set
- ✅ Maneja intervalos y operaciones matemáticas avanzadas
- ✅ Persistencia opcional en SQLite
- ✅ Ejecutables monolíticos sin dependencias externas
- ✅ Pipeline automatizado con script shell

Características Principales

- 🚀 Pipeline de 7 Etapas: Validación → AST → Funciones → Forward → Backward → Gecode → Verificación (opcional)
- 📊 4 Tipos de Datos: Enteros, flotantes, lógicos y conjuntos
- 🔗 Puente C++/Pascal: Interfaz limpia a Gecode mediante FFI
- 🧮 Biblioteca Matemática: MiniMath en C con funciones trigonométricas, exponenciales e intervalos
- 💾 Persistencia SQLite: Almacenamiento opcional de cada etapa del pipeline
- 🎯 AC-3: Algoritmo de propagación de restricciones Arc Consistency
- 📦 Compilación Monolítica: Ejecutables standalone de ~8-12 MB
- 🔍 Parser Pratt: Análisis sintáctico eficiente de expresiones
- ✅ Verificación Cruzada: Integración con GNUBison para validar soluciones

Compilación

Compilación Completa

```bash
make
```

Compilación Selectiva

```bash
Solo herramientas del pipeline (sin Gecode)
make pipeline

Solo herramientas Gecode
make gecode
```

Limpieza

```bash
make clean        # Solo archivos objeto
make distclean    # Archivos objeto + ejecutables
```

Estructura del Proyecto

```
gecode/
├── bin/              # Binarios compilados
├── src/              # Código fuente (Pascal + C/C++)
├── obj/              # Archivos objeto (compilación)
├── docs/             # Documentación
├── ejemplos/         # Archivos JSON de ejemplo
├── tests/            # Tests y casos de prueba
├── scripts/          # Scripts auxiliares
│   ├── build_monolithic.sh  # Compilación monolítica
│   └── pipeline.sh          # Ejecución del pipeline completo
├── Makefile          # Sistema de compilación
└── README.md         # Este archivo
```

Componentes del Pipeline

1. SyntaxChecker
Valida la sintaxis del archivo JSON de entrada.

```bash
./bin/SyntaxChecker ejemplos/Json_input_1.json
```

2. JsonToGraph
Construye un grafo AST de las restricciones.

```bash
./bin/JsonToGraph ejemplos/Json_input_1.json
```

3. FunctionChecker
Verifica objetos de funciones user-defined.

```bash
./bin/FunctionChecker graph.json
```

4. FwdConsistency
Propagación hacia adelante (AC-3).

```bash
./bin/FwdConsistency graph.json
```

5. BwdConsistency
Proyección inversa de restricciones.

```bash
./bin/BwdConsistency graph.json
```

6. TestGecodeBridge
Resolución CSP completa con Gecode.

```bash
./bin/TestGecodeBridge graph.json
```

7. VerifyWithBison (Opcional)
Verificación de soluciones con GNUBison.

```bash
./bin/TestGecodeBridge graph.json | ./bin/VerifyWithBison graph.json
```

Características:
- Validación cruzada: Gecode resuelve, GNUBison verifica
- Transformación automática de formatos (boolean→logic, numeric→float, set→labels)
- Reporte JSON con estadísticas de verificación
- Integrable en pipeline con flag --verify-bison

Herramientas de Persistencia

JsonSink
Almacena JSON en base de datos SQLite.

```bash
./bin/JsonSink db.sqlite tag_name < data.json
```

JsonSource
Recupera JSON desde SQLite.

```bash
./bin/JsonSource db.sqlite tag_name
```

Uso del Pipeline Completo

El script pipeline.sh ejecuta todas las etapas automáticamente:

```bash
Básico
./scripts/pipeline.sh ejemplos/Json_input_1.json

Con verificación GNUBison
./scripts/pipeline.sh --verify-bison ejemplos/Json_input_1.json

Con persistencia en SQLite
./scripts/pipeline.sh --db runs.db --tag test_1 ejemplos/Json_input_1.json

Pipeline completo con verificación y persistencia
./scripts/pipeline.sh --db runs.db --verify-bison --tag verified_run ejemplos/Json_input_1.json

Múltiples archivos con persistencia
./scripts/pipeline.sh --db runs.db ejemplos/*.json
```

Opciones:
- --db FILE: Persiste cada etapa en SQLite
- --tag TAG: Tag para los registros (default: nombre del archivo)
- --path DIRS: Path de búsqueda para FunctionChecker (dir1:dir2:...)

Formato de Entrada JSON

```json
{
  "precision": 2,
  "variables": [
    {
      "nombre": "x",
      "tipo": "integer",
      "domain": [1, 100],
      "value": 10
    },
    {
      "nombre": "y",
      "tipo": "float",
      "domain": [0.0, 50.0],
      "value": 15.5
    }
  ],
  "expresiones": [
    "x + y * 2",
    "x > 5"
  ]
}
```

Tipos Soportados

- integer: Números enteros
- float: Números de punto flotante
- logic: Booleanos (true/false o 0/1)
- set: Conjuntos de valores

Operadores

- Aritméticos: +, -, *, /
- Comparación: =, <>, <, >, <=, >=
- Lógicos: AND, OR, NOT, IMPLICA
- Conjuntos: UNION, INTERSECT, DIFFERENCE, SUBSET, CARDINALITY, IN

Compilación Monolítica

Para crear ejecutables standalone sin dependencias externas:

```bash
./scripts/build_monolithic.sh src/TestGecodeBridge.pas
```

Esto genera un ejecutable con:
- ✅ Todo el código Pascal
- ✅ Puente C++ a Gecode
- ✅ Gecode linkeado estáticamente
- ✅ Sin dependencias de libgecode*.so
- ✅ ~8-12 MB de tamaño

Modos de Compilación

Modo estático: Si existe $GECODE_HOME con archivos .a, linkea estático.

Modo dinámico: Si solo hay .so del sistema, linkea dinámico.

Herramientas de Evaluación

CSPEval
Evaluador de expresiones CSP con cálculo de resultados.

```bash
./bin/CSPEval input.json
```

ForwardChain
Encadenamiento hacia adelante para inferencia lógica.

```bash
./bin/ForwardChain graph.json
```

Ejemplos

El directorio ejemplos/ contiene archivos JSON de entrada y salida de ejemplo:

- Json_input_*.json - Archivos de entrada de prueba
- Json_output_*.json - Salidas esperadas correspondientes

Requisitos

Compilación del Pipeline
- Free Pascal Compiler (fpc)
- gcc
- SQLite3 (libsqlite3-dev)
- make

Compilación con Gecode
- g++
- Gecode 6.x (estático o dinámico)
- Free Pascal Compiler (fpc)

Instalación de Gecode Estático

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

export GECODE_HOME=$HOME/gecode-static
```

📚 Documentación

La documentación completa está disponible en el directorio docs/:

Documentos Principales

- README.md - Índice de documentación y guía de PDFs
- 01_introduccion.md - Introducción, arquitectura y compilación
- 02_arquitectura.md - Diseño del sistema y flujo de datos
- 03_componentes_pipeline.md - Detalles de cada componente del pipeline
- 04_integracion_gecode.md - Puente C++/Pascal y API Gecode
- estructura_proyecto.md - Organización de directorios y dependencias

Documentación Técnica de Componentes

- SyntaxChecker.txt - Validador de sintaxis JSON
- JsonToGraph.txt - Constructor de grafos AST
- FunctionChecker.txt - Verificador de funciones definidas
- FwdConsistency.txt - Propagación forward (AC-3)
- BwdConsistency.txt - Proyección inversa de restricciones
- CSPEval.txt - Evaluador de expresiones CSP
- TestGecodeBridge.txt - Integración completa con Gecode
- monolitico.txt - Guía de compilación monolítica

Reportes de Pruebas

- reporte_prueba_pipeline_basico.md - Pruebas básicas del pipeline
- reporte_prueba_gecode_completo.md - Pruebas de integración Gecode
- reporte_prueba_persistencia_sqlite.md - Pruebas de persistencia

Generar PDFs

```bash
./generar_pdfs.sh
```

Los PDFs se generan en docs/pdf/

🚀 Inicio Rápido

```bash
1. Compilar el proyecto
make

2. Ejecutar el pipeline completo
./scripts/pipeline.sh ejemplos/Json_input_1.json

3. Con persistencia en SQLite
./scripts/pipeline.sh --db runs.db --tag mi_prueba ejemplos/Json_input_1.json

4. Procesar múltiples ejemplos
./scripts/pipeline.sh --db runs.db ejemplos/*.json
```

🏗️ Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────┐
│                        JSON Input                            │
│         (variables, dominios, expresiones, funciones)        │
└─────────────────────┬───────────────────────────────────────┘
                      ↓
          ┌───────────────────────┐
          │   SyntaxChecker       │  ← Validación sintáctica JSON
          │   (Pascal + MiniJSON) │
          └───────────┬───────────┘
                      ↓
          ┌───────────────────────┐
          │   JsonToGraph         │  ← Construcción de AST
          │   (PrattParser)       │     y grafo de restricciones
          └───────────┬───────────┘
                      ↓
          ┌───────────────────────┐
          │   FunctionChecker     │  ← Verificación de funciones
          │   (UCSPJson)          │     definidas por usuario
          └───────────┬───────────┘
                      ↓
          ┌───────────────────────┐
          │   FwdConsistency      │  ← Propagación AC-3
          │   (MiniMath + AC3)    │     (Arc Consistency)
          └───────────┬───────────┘
                      ↓
          ┌───────────────────────┐
          │   BwdConsistency      │  ← Proyección inversa
          │   (Interval Analysis) │     de restricciones
          └───────────┬───────────┘
                      ↓
          ┌───────────────────────┐
          │  TestGecodeBridge     │  ← Resolución CSP completa
          │  (C++ Bridge→Gecode)  │     con Gecode solver
          └───────────┬───────────┘
                      ↓
┌─────────────────────────────────────────────────────────────┐
│                       JSON Output                            │
│              (soluciones, estadísticas)                      │
└─────────────────────────────────────────────────────────────┘

           Persistencia Opcional (SQLite)
                    JsonSink ⇄ JsonSource
```

Persistencia Opcional (SQLite)

Cada etapa puede persistirse en SQLite usando JsonSink/JsonSource:

```
JSON → SyntaxChecker → JsonSink (db: syntax)
       JsonSource ↓
       JsonToGraph → JsonSink (db: graph)
       JsonSource ↓
       ...
```

Autor

Proyecto Gecode CSP Pipeline

Licencia

Consultar licencias individuales de componentes:
- Free Pascal: GPL/LGPL
- Gecode: MIT License

--------------------------------------------------------------------------------

EJECUTABLES
-----------

Este proyecto contiene 14 ejecutable(s) en el directorio bin/:

  * VerifyWithBison
    Ejecutable compilado (ELF)

  * CSPEval
    Ejecutable compilado (ELF)

  * BwdConsistency
    Ejecutable compilado (ELF)

  * JsonSource
    Ejecutable compilado (ELF)

  * TestComplejo
    Ejecutable compilado (ELF)

  * JsonSink
    Ejecutable compilado (ELF)

  * TestGecodeBridge
    Ejecutable compilado (ELF)

  * FunctionChecker
    Ejecutable compilado (ELF)

  * TestIntervalos
    Ejecutable compilado (ELF)

  * SyntaxChecker
    Ejecutable compilado (ELF)

  * JsonToGraph
    Ejecutable compilado (ELF)

  * FwdConsistency
    Ejecutable compilado (ELF)

  * GecodeInfo
    Ejecutable compilado (ELF)

  * ForwardChain
    Ejecutable compilado (ELF)


CÓMO EJECUTAR
-------------

Desde el directorio raíz del proyecto:

  ./bin/[nombre_ejecutable]

Ejemplo:
  ./bin/VerifyWithBison


--------------------------------------------------------------------------------
ESTRUCTURA DEL PROYECTO
-----------------------

  /bin/         - Ejecutables compilados
  /docs/        - Documentación
  /ejemplos/    - Archivos de ejemplo
  /obj/         - Archivos objeto (compilación)
  /src/         - Código fuente
  /tests/       - Tests y pruebas

COMPILACIÓN
-----------

Para compilar el proyecto:

  make

Para limpiar archivos generados:

  make clean

Para ejecutar tests:

  make test
  # o directamente:
  ./probar_todos.sh

