---
title: "GeCode CSP Pipeline - Arquitectura del Sistema"
subtitle: "Diseño, Flujo de Datos y Componentes"
author: "Proyecto GeCode CSP Pipeline"
date: "2026"
geometry: margin=2.5cm
fontsize: 11pt
colorlinks: true
---

\newpage

# Visión General de la Arquitectura

## Filosofía de Diseño

El GeCode CSP Pipeline sigue una arquitectura de **pipeline modular** donde cada componente tiene una responsabilidad única y bien definida. Los datos fluyen secuencialmente a través de etapas de transformación y verificación.

### Principios de Diseño

1. **Separación de Responsabilidades**: Cada herramienta hace una cosa y la hace bien
2. **Formato JSON**: Comunicación entre componentes mediante JSON estructurado
3. **Composabilidad**: Las herramientas pueden usarse independientemente o en pipeline
4. **Persistencia Opcional**: SQLite permite almacenar/recuperar estados intermedios
5. **Compilación Flexible**: Soporte para compilación modular o monolítica

## Arquitectura de Alto Nivel

```
┌─────────────────────────────────────────────────────────────────┐
│                           ENTRADA                                │
│                     (JSON CSP Problem)                           │
└──────────────────────┬──────────────────────────────────────────┘
                       │
    ┌──────────────────▼──────────────────┐
    │      CAPA DE VALIDACIÓN             │
    │  ┌──────────────────────────────┐   │
    │  │   SyntaxChecker              │   │  ← Valida JSON y sintaxis
    │  └──────────────┬───────────────┘   │
    └─────────────────┼───────────────────┘
                       │
    ┌──────────────────▼──────────────────┐
    │   CAPA DE ANÁLISIS SINTÁCTICO       │
    │  ┌──────────────────────────────┐   │
    │  │   JsonToGraph                │   │  ← Construye AST y grafo
    │  │   (PrattParser)              │   │
    │  └──────────────┬───────────────┘   │
    └─────────────────┼───────────────────┘
                       │
    ┌──────────────────▼──────────────────┐
    │   CAPA DE VERIFICACIÓN SEMÁNTICA    │
    │  ┌──────────────────────────────┐   │
    │  │   FunctionChecker            │   │  ← Verifica funciones
    │  └──────────────┬───────────────┘   │
    └─────────────────┼───────────────────┘
                       │
    ┌──────────────────▼──────────────────┐
    │   CAPA DE PROPAGACIÓN               │
    │  ┌──────────────────────────────┐   │
    │  │   FwdConsistency (AC-3)      │   │  ← Propagación forward
    │  └──────────────┬───────────────┘   │
    │  ┌──────────────▼───────────────┐   │
    │  │   BwdConsistency             │   │  ← Propagación backward
    │  └──────────────┬───────────────┘   │
    └─────────────────┼───────────────────┘
                       │
    ┌──────────────────▼──────────────────┐
    │   CAPA DE RESOLUCIÓN                │
    │  ┌──────────────────────────────┐   │
    │  │   TestGecodeBridge           │   │  ← Solver Gecode
    │  │   (C++ Bridge → Gecode)      │   │
    │  └──────────────┬───────────────┘   │
    └─────────────────┼───────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│                          SALIDA                                  │
│                  (JSON con Soluciones)                           │
└──────────────────────────────────────────────────────────────────┘

        Persistencia Opcional (SQLite)
┌──────────────────────────────────────────┐
│  JsonSink    ⇄    JsonSource             │  ← Almacenamiento
└──────────────────────────────────────────┘
```

\newpage

# Componentes del Sistema

## 1. SyntaxChecker

**Propósito**: Validar la sintaxis del archivo JSON de entrada

**Entrada**: Archivo JSON
**Salida**: JSON validado o mensaje de error

```
Funciones:
- Verificar estructura JSON válida
- Validar campos obligatorios (precision, variables, expresiones)
- Verificar tipos de datos
- Reportar errores de sintaxis
```

**Tecnologías**: Pascal + MiniJSON

## 2. JsonToGraph

**Propósito**: Construir el AST y grafo de restricciones

**Entrada**: JSON validado
**Salida**: Grafo JSON con AST de expresiones

```
Funciones:
- Parsear expresiones con PrattParser
- Construir árbol de sintaxis abstracta
- Generar grafo de dependencias
- Identificar nodos y aristas
```

**Tecnologías**: Pascal + PrattParser + ExpressionAST

## 3. FunctionChecker

**Propósito**: Verificar funciones definidas por el usuario

**Entrada**: Grafo JSON
**Salida**: Grafo verificado

```
Funciones:
- Validar definiciones de funciones
- Verificar parámetros y tipos
- Comprobar referencias válidas
- Marcar funciones válidas/inválidas
```

**Tecnologías**: Pascal + UCSPJson

## 4. FwdConsistency

**Propósito**: Propagación de restricciones hacia adelante (AC-3)

**Entrada**: Grafo verificado
**Salida**: Grafo con dominios reducidos

```
Funciones:
- Implementar algoritmo AC-3
- Reducir dominios de variables
- Propagar restricciones forward
- Detectar inconsistencias tempranas
```

**Tecnologías**: Pascal + MiniMath + AC-3 Algorithm

## 5. BwdConsistency

**Propósito**: Proyección inversa de restricciones

**Entrada**: Grafo con dominios reducidos
**Salida**: Grafo con análisis de intervalos

```
Funciones:
- Análisis de intervalos
- Proyección inversa de restricciones
- Refinamiento de dominios
- Propagación backward
```

**Tecnologías**: Pascal + MiniMath + Interval Analysis

## 6. TestGecodeBridge

**Propósito**: Resolución CSP completa con Gecode

**Entrada**: Grafo optimizado
**Salida**: JSON con soluciones

```
Funciones:
- Traducir CSP a modelo Gecode
- Configurar variables y restricciones
- Ejecutar búsqueda
- Retornar soluciones encontradas
```

**Tecnologías**: Pascal + C++ Bridge + Gecode Solver

## Herramientas Auxiliares

### CSPEval
Evaluador de expresiones CSP con cálculo de resultados

### ForwardChain
Encadenamiento hacia adelante para inferencia lógica

### JsonSink / JsonSource
Persistencia y recuperación desde SQLite

\newpage

# Flujo de Datos

## Formato JSON de Entrada

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
  ],
  "funciones": [
    {
      "nombre": "miFuncion",
      "parametros": ["a", "b"],
      "salida": "a + b * 2"
    }
  ]
}
```

## Transformaciones por Etapa

### Etapa 1: SyntaxChecker → JSON Validado

```json
{
  "valido": true,
  "errores": [],
  "precision": 2,
  "variables": [...],
  "expresiones": [...]
}
```

### Etapa 2: JsonToGraph → Grafo con AST

```json
{
  "precision": 2,
  "variables": [...],
  "expresiones": [
    {
      "texto": "x + y * 2",
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
  ],
  "grafo": {
    "nodos": [...],
    "aristas": [...]
  }
}
```

### Etapa 3: FunctionChecker → Grafo Verificado

```json
{
  "funciones_verificadas": true,
  "funciones": [
    {
      "nombre": "miFuncion",
      "valida": true,
      "mensaje": "OK"
    }
  ],
  ...
}
```

### Etapa 4-5: Propagación → Dominios Reducidos

```json
{
  "variables": [
    {
      "nombre": "x",
      "domain_original": [1, 100],
      "domain_reducido": [6, 100]  ← Después de x > 5
    }
  ],
  ...
}
```

### Etapa 6: TestGecodeBridge → Soluciones

```json
{
  "num_soluciones": 3,
  "soluciones": [
    {
      "x": 10,
      "y": 15.5
    },
    {
      "x": 11,
      "y": 14.25
    },
    {
      "x": 12,
      "y": 13.0
    }
  ],
  "estadisticas": {
    "tiempo_ms": 42,
    "nodos_explorados": 156
  }
}
```

\newpage

# Arquitectura de Persistencia

## SQLite como Almacenamiento Intermedio

El sistema permite **persistir cada etapa del pipeline** en una base de datos SQLite mediante las herramientas **JsonSink** y **JsonSource**.

### Esquema de Base de Datos

```sql
CREATE TABLE json_storage (
    tag TEXT PRIMARY KEY,
    timestamp INTEGER,
    json_data TEXT
);
```

### Flujo con Persistencia

```
Input JSON
    ↓
SyntaxChecker → JsonSink(db, "problema1_syntax")
                    ↓
           JsonSource(db, "problema1_syntax")
                    ↓
JsonToGraph → JsonSink(db, "problema1_graph")
                    ↓
           JsonSource(db, "problema1_graph")
                    ↓
FunctionChecker → JsonSink(db, "problema1_checked")
                    ↓
                  ...
```

### Ventajas de la Persistencia

1. **Debugging**: Inspeccionar estado en cualquier etapa
2. **Reproducibilidad**: Re-ejecutar desde cualquier punto
3. **Análisis**: Comparar resultados de múltiples ejecuciones
4. **Cacheo**: Evitar re-computar etapas costosas

### Uso

```bash
# Almacenar JSON
echo '{"data": "value"}' | ./bin/JsonSink db.sqlite mi_tag

# Recuperar JSON
./bin/JsonSource db.sqlite mi_tag

# Pipeline completo con persistencia
./scripts/pipeline.sh --db runs.db --tag test_1 input.json
```

\newpage

# Integración de Lenguajes

## Pascal + C/C++ + Gecode

El proyecto integra **tres lenguajes** de forma eficiente:

### 1. Pascal (Free Pascal)

**Usado para**:
- Herramientas del pipeline
- Parsing y validación
- Lógica de negocio
- Interfaz de línea de comandos

**Ventajas**:
- Compilación rápida
- Ejecutables eficientes
- Sintaxis clara y legible
- Excelente para procesamiento de texto

### 2. C (Biblioteca MiniMath)

**Usado para**:
- Funciones matemáticas (sin, cos, exp, ln)
- Operaciones de intervalos
- Cálculos de precisión

**Integración**:
```pascal
{$LINKLIB minimath}
{$L minimath_trig.o}
{$L minimath_exp.o}
{$L minimath_interval.o}

function c_sin(x: cdouble): cdouble; cdecl; external;
function c_cos(x: cdouble): cdouble; cdecl; external;
```

### 3. C++ (Gecode Bridge)

**Usado para**:
- Interfaz a Gecode
- Resolución CSP
- Búsqueda y optimización

**Integración Pascal → C++**:
```pascal
// UGecodeBridge.pas
function csp_create(vars: PVariable; n: cint): pointer; cdecl; external;
function csp_solve(model: pointer; sol: PSolution): cint; cdecl; external;
```

```cpp
// gecode_bridge.cpp
extern "C" {
    void* csp_create(Variable* vars, int n) { ... }
    int csp_solve(void* model, Solution* sol) { ... }
}
```

## Diagrama de Integración

```
┌─────────────────────────────────────────────┐
│         Pascal (Free Pascal)                │
│  ┌─────────────────────────────────────┐   │
│  │  Pipeline Tools                     │   │
│  │  - SyntaxChecker                    │   │
│  │  - JsonToGraph                      │   │
│  │  - FwdConsistency                   │   │
│  └─────────┬───────────────────────────┘   │
│            │ {$LINKLIB}                     │
│            ▼                                │
│  ┌─────────────────────────────────────┐   │
│  │  MiniMath (C)                       │   │
│  │  - minimath_trig.o                  │   │
│  │  - minimath_exp.o                   │   │
│  │  - minimath_interval.o              │   │
│  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│         Pascal + C++ Bridge                 │
│  ┌─────────────────────────────────────┐   │
│  │  TestGecodeBridge.pas               │   │
│  │  (Programa Pascal)                  │   │
│  └─────────┬───────────────────────────┘   │
│            │ external cdecl               │
│            ▼                                │
│  ┌─────────────────────────────────────┐   │
│  │  UGecodeBridge.pas                  │   │
│  │  (Interface Unit)                   │   │
│  └─────────┬───────────────────────────┘   │
│            │ FFI                            │
│            ▼                                │
│  ┌─────────────────────────────────────┐   │
│  │  gecode_bridge.cpp                  │   │
│  │  (C API Wrapper)                    │   │
│  └─────────┬───────────────────────────┘   │
│            │                                │
│            ▼                                │
│  ┌─────────────────────────────────────┐   │
│  │  Gecode (C++ Library)               │   │
│  │  - IntVarArray                      │   │
│  │  - Constraints                      │   │
│  │  - Search                           │   │
│  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

\newpage

# Sistema de Compilación

## Makefile Modular

El Makefile permite compilar componentes de forma **selectiva**:

```makefile
all: pipeline gecode

pipeline: minimath json_tools propagation_tools persistence_tools

gecode: gecode_bridge gecode_tools

minimath:
    gcc -c src/minimath_*.c

json_tools:
    fpc src/JsonToGraph.pas
    fpc src/SyntaxChecker.pas

gecode_bridge:
    g++ -c src/gecode_bridge.cpp -I$(GECODE_HOME)/include

gecode_tools:
    ./scripts/build_monolithic.sh src/TestGecodeBridge.pas
```

## Compilación Monolítica

El script `build_monolithic.sh` genera **ejecutables standalone**:

```bash
#!/bin/bash
# 1. Compilar bridge C++
g++ -c gecode_bridge.cpp

# 2. Compilar Pascal con linkeo explícito
fpc TestGecodeBridge.pas \
    -FU obj/ \
    -k'-L/path/to/gecode/lib' \
    -k'-lgecodekernel' \
    -k'-lgecodesupport' \
    -k gecode_bridge.o

# Resultado: ejecutable standalone de ~8-12 MB
```

### Modos de Linkeo

1. **Estático**: Si existe `$GECODE_HOME/lib/*.a`
   - Linkea libgecode*.a estáticamente
   - No requiere libgecode*.so en runtime
   - Ejecutable más grande (~12 MB)

2. **Dinámico**: Si solo hay `/usr/lib/libgecode*.so`
   - Linkea dinámicamente
   - Requiere libgecode*.so instaladas
   - Ejecutable más pequeño (~500 KB)

## Diagrama de Compilación

```
src/*.pas + src/*.c + src/*.cpp
            │
            ▼
    ┌───────────────────┐
    │   Makefile        │
    └───────┬───────────┘
            │
    ┌───────▼────────────────────────┐
    │   Compilación Modular          │
    │                                │
    │  fpc → obj/*.ppu + obj/*.o     │
    │  gcc → obj/*.o                 │
    │  g++ → obj/*.o                 │
    └───────┬────────────────────────┘
            │
    ┌───────▼────────────────────────┐
    │   Linkeo                       │
    │                                │
    │  pipeline: solo Pascal + C     │
    │  gecode: Pascal + C + C++      │
    └───────┬────────────────────────┘
            │
            ▼
       bin/[ejecutables]
```

---

**Próximo**: Leer **03_componentes_pipeline.md** para detalles técnicos de cada componente.
