-   [[1]{.toc-section-number} Comparación de Sintaxis: Gecode vs
    GNUBison](#comparación-de-sintaxis-gecode-vs-gnubison){#toc-comparación-de-sintaxis-gecode-vs-gnubison}
    -   [[1.1]{.toc-section-number} Tabla de
        Contenidos](#tabla-de-contenidos){#toc-tabla-de-contenidos}
    -   [[1.2]{.toc-section-number} 1.
        Introducción](#introducción){#toc-introducción}
        -   [[1.2.1]{.toc-section-number} 1.1
            Propósito](#propósito){#toc-propósito}
        -   [[1.2.2]{.toc-section-number} 1.2 Diferencias
            Fundamentales](#diferencias-fundamentales){#toc-diferencias-fundamentales}
        -   [[1.2.3]{.toc-section-number} 1.3 Convenciones de este
            Documento](#convenciones-de-este-documento){#toc-convenciones-de-este-documento}
    -   [[1.3]{.toc-section-number} 2. Sintaxis
        Gecode](#sintaxis-gecode){#toc-sintaxis-gecode}
        -   [[1.3.1]{.toc-section-number} 2.1 Estructura
            General](#estructura-general){#toc-estructura-general}
        -   [[1.3.2]{.toc-section-number} 2.2 Sección de
            Variables](#sección-de-variables){#toc-sección-de-variables}
        -   [[1.3.3]{.toc-section-number} 2.3 Sección de Restricciones
            (Constraints)](#sección-de-restricciones-constraints){#toc-sección-de-restricciones-constraints}
        -   [[1.3.4]{.toc-section-number} 2.4 Sección de
            Funciones](#sección-de-funciones){#toc-sección-de-funciones}
        -   [[1.3.5]{.toc-section-number} 2.5 Ejemplo Completo
            Gecode](#ejemplo-completo-gecode){#toc-ejemplo-completo-gecode}
    -   [[1.4]{.toc-section-number} 3. Sintaxis
        GNUBison](#sintaxis-gnubison){#toc-sintaxis-gnubison}
        -   [[1.4.1]{.toc-section-number} 3.1 Estructura
            General](#estructura-general-1){#toc-estructura-general-1}
        -   [[1.4.2]{.toc-section-number} 3.2 Sección de
            Variables](#sección-de-variables-1){#toc-sección-de-variables-1}
        -   [[1.4.3]{.toc-section-number} 3.3 Sección de
            Expresiones](#sección-de-expresiones){#toc-sección-de-expresiones}
        -   [[1.4.4]{.toc-section-number} 3.4 Formato de
            Salida](#formato-de-salida){#toc-formato-de-salida}
        -   [[1.4.5]{.toc-section-number} 3.5 Ejemplo Completo
            GNUBison](#ejemplo-completo-gnubison){#toc-ejemplo-completo-gnubison}
    -   [[1.5]{.toc-section-number} 4. Comparación
        Detallada](#comparación-detallada){#toc-comparación-detallada}
        -   [[1.5.1]{.toc-section-number} 4.1 Tabla Comparativa: Campos
            de
            Variables](#tabla-comparativa-campos-de-variables){#toc-tabla-comparativa-campos-de-variables}
        -   [[1.5.2]{.toc-section-number} 4.2 Tabla Comparativa: Tipos
            de
            Datos](#tabla-comparativa-tipos-de-datos){#toc-tabla-comparativa-tipos-de-datos}
        -   [[1.5.3]{.toc-section-number} 4.3 Tabla Comparativa:
            Valores](#tabla-comparativa-valores){#toc-tabla-comparativa-valores}
        -   [[1.5.4]{.toc-section-number} 4.4 Tabla Comparativa:
            Expresiones](#tabla-comparativa-expresiones){#toc-tabla-comparativa-expresiones}
        -   [[1.5.5]{.toc-section-number} 4.5 Tabla Comparativa:
            Estructura
            General](#tabla-comparativa-estructura-general){#toc-tabla-comparativa-estructura-general}
    -   [[1.6]{.toc-section-number} 5. Gramática
        Formal](#gramática-formal){#toc-gramática-formal}
        -   [[1.6.1]{.toc-section-number} 5.1 Gramática Gecode
            (EBNF)](#gramática-gecode-ebnf){#toc-gramática-gecode-ebnf}
        -   [[1.6.2]{.toc-section-number} 5.2 Gramática GNUBison
            (EBNF)](#gramática-gnubison-ebnf){#toc-gramática-gnubison-ebnf}
    -   [[1.7]{.toc-section-number} 6.
        Transformaciones](#transformaciones){#toc-transformaciones}
        -   [[1.7.1]{.toc-section-number} 6.1 Transformación Gecode →
            GNUBison](#transformación-gecode-gnubison){#toc-transformación-gecode-gnubison}
        -   [[1.7.2]{.toc-section-number} 6.2 Algoritmo de
            Transformación](#algoritmo-de-transformación){#toc-algoritmo-de-transformación}
    -   [[1.8]{.toc-section-number} 7. Ejemplos
        Completos](#ejemplos-completos){#toc-ejemplos-completos}
        -   [[1.8.1]{.toc-section-number} 7.1 Ejemplo: Sistema de
            Control de
            Acceso](#ejemplo-sistema-de-control-de-acceso){#toc-ejemplo-sistema-de-control-de-acceso}
        -   [[1.8.2]{.toc-section-number} 7.2 Ejemplo: Sistema de
            Monitoreo de
            Temperatura](#ejemplo-sistema-de-monitoreo-de-temperatura){#toc-ejemplo-sistema-de-monitoreo-de-temperatura}
    -   [[1.9]{.toc-section-number} 8. Referencia
        Rápida](#referencia-rápida){#toc-referencia-rápida}
        -   [[1.9.1]{.toc-section-number} 8.1 Gecode - Cheat
            Sheet](#gecode---cheat-sheet){#toc-gecode---cheat-sheet}
        -   [[1.9.2]{.toc-section-number} 8.2 GNUBison - Cheat
            Sheet](#gnubison---cheat-sheet){#toc-gnubison---cheat-sheet}
        -   [[1.9.3]{.toc-section-number} 8.3 Tabla de Transformación
            Rápida](#tabla-de-transformación-rápida){#toc-tabla-de-transformación-rápida}
    -   [[1.10]{.toc-section-number} 9.
        Apéndices](#apéndices){#toc-apéndices}
        -   [[1.10.1]{.toc-section-number} 9.1 Apéndice A: Operadores
            Completos](#apéndice-a-operadores-completos){#toc-apéndice-a-operadores-completos}
        -   [[1.10.2]{.toc-section-number} 9.2 Apéndice B: Funciones
            Disponibles](#apéndice-b-funciones-disponibles){#toc-apéndice-b-funciones-disponibles}
        -   [[1.10.3]{.toc-section-number} 9.3 Apéndice C: Códigos de
            Error](#apéndice-c-códigos-de-error){#toc-apéndice-c-códigos-de-error}
        -   [[1.10.4]{.toc-section-number} 9.4 Apéndice D: Herramientas
            de
            Conversión](#apéndice-d-herramientas-de-conversión){#toc-apéndice-d-herramientas-de-conversión}
        -   [[1.10.5]{.toc-section-number} 9.5 Apéndice E: Recursos
            Adicionales](#apéndice-e-recursos-adicionales){#toc-apéndice-e-recursos-adicionales}
    -   [[1.11]{.toc-section-number} Glosario](#glosario){#toc-glosario}

# [1]{.header-section-number} Comparación de Sintaxis: Gecode vs GNUBison {#comparación-de-sintaxis-gecode-vs-gnubison number="1"}

**Documento de Referencia Técnica** **Versión:** 1.0 **Fecha:** Febrero
2026 **Autores:** Pipeline CSP - Motor Lógico Tipado Multidominio

------------------------------------------------------------------------

## [1.1]{.header-section-number} Tabla de Contenidos {#tabla-de-contenidos number="1.1"}

1.  [Introducción](#introducción)
2.  [Sintaxis Gecode](#sintaxis-gecode)
3.  [Sintaxis GNUBison](#sintaxis-gnubison)
4.  [Comparación Detallada](#comparación-detallada)
5.  [Gramática Formal](#gramática-formal)
6.  [Transformaciones](#transformaciones)
7.  [Ejemplos Completos](#ejemplos-completos)
8.  [Referencia Rápida](#referencia-rápida)
9.  [Apéndices](#apéndices)

------------------------------------------------------------------------

## [1.2]{.header-section-number} 1. Introducción {#introducción number="1.2"}

### [1.2.1]{.header-section-number} 1.1 Propósito {#propósito number="1.2.1"}

Este documento proporciona una comparación exhaustiva entre dos formatos
de especificación de problemas lógicos:

-   **Gecode**: Formato de entrada para el pipeline CSP (Constraint
    Satisfaction Problems)
-   **GNUBison**: Formato de evaluación de expresiones con soporte de
    incertidumbre

### [1.2.2]{.header-section-number} 1.2 Diferencias Fundamentales {#diferencias-fundamentales number="1.2.2"}

  -----------------------------------------------------------------------
  Aspecto                 Gecode               GNUBison
  ----------------------- -------------------- --------------------------
  **Propósito**           Definir y resolver   Evaluar expresiones con
                          CSP                  valores concretos

  **Paradigma**           Solver de            Evaluador de expresiones
                          restricciones        

  **Incertidumbre**       No soporta           Soporta múltiples valores
                                               simultáneos

  **Formato**             JSON con AST de      JSON con variables y
                          restricciones        expresiones

  **Salida**              Soluciones que       Evaluación de verdad de
                          satisfacen           expresiones
                          restricciones        
  -----------------------------------------------------------------------

### [1.2.3]{.header-section-number} 1.3 Convenciones de este Documento {#convenciones-de-este-documento number="1.2.3"}

-   **Código en monospace**: `ejemplo`
-   **Palabras clave en negrita**: **boolean**, **integer**
-   **Variables en MAYÚSCULAS**: `TEMPERATURA`, `ZONA`
-   **Tipos en cursiva**: *logic*, *set*, *float*

------------------------------------------------------------------------

## [1.3]{.header-section-number} 2. Sintaxis Gecode {#sintaxis-gecode number="1.3"}

### [1.3.1]{.header-section-number} 2.1 Estructura General {#estructura-general number="1.3.1"}

El formato Gecode usa JSON con tres secciones principales:

::: {#cb1 .sourceCode}
``` {.sourceCode .json}
{
  "variables": [ ... ],
  "functions": [ ... ],
  "constraints": [ ... ]
}
```
:::

### [1.3.2]{.header-section-number} 2.2 Sección de Variables {#sección-de-variables number="1.3.2"}

#### [1.3.2.1]{.header-section-number} 2.2.1 Estructura de Variable {#estructura-de-variable number="1.3.2.1"}

::: {#cb2 .sourceCode}
``` {.sourceCode .json}
{
  "name": "NOMBRE_VARIABLE",
  "type": "tipo",
  "domain": [ valores_posibles ],
  "value": [ valores_iniciales ],
  "id": identificador_numérico
}
```
:::

#### [1.3.2.2]{.header-section-number} 2.2.2 Tipos de Variables {#tipos-de-variables number="1.3.2.2"}

##### [1.3.2.2.1]{.header-section-number} Tipo: **boolean** {#tipo-boolean number="1.3.2.2.1"}

**Descripción:** Variable lógica binaria (verdadero/falso)

**Representación interna:** Integer 0/1 (false=0, true=1)

**Ejemplo:**

::: {#cb3 .sourceCode}
``` {.sourceCode .json}
{
  "name": "PUERTA_ABIERTA",
  "type": "boolean",
  "domain": [true, false],
  "value": [false],
  "id": 0
}
```
:::

**Interpretación:** - `domain`: Valores posibles (siempre
`[true, false]` para booleanos) - `value`: Valores iniciales permitidos
(subset del dominio) - Internamente Gecode usa 0 (false) y 1 (true)

##### [1.3.2.2.2]{.header-section-number} Tipo: **integer** {#tipo-integer number="1.3.2.2.2"}

**Descripción:** Variable entera con dominio discreto

**Representación interna:** Integer nativo

**Ejemplo:**

::: {#cb4 .sourceCode}
``` {.sourceCode .json}
{
  "name": "INTENTOS",
  "type": "integer",
  "domain": [0, 1, 2, 3, 4, 5],
  "value": [0, 1],
  "id": 8
}
```
:::

**Interpretación:** - `domain`: Lista explícita de valores enteros
permitidos - `value`: Subset del dominio como valores iniciales - No
requiere que el dominio sea continuo

##### [1.3.2.2.3]{.header-section-number} Tipo: **numeric** {#tipo-numeric number="1.3.2.2.3"}

**Descripción:** Variable numérica de punto flotante

**Representación interna:** Integer escalado × 1000

**Ejemplo:**

::: {#cb5 .sourceCode}
``` {.sourceCode .json}
{
  "name": "TEMPERATURA_C",
  "type": "numeric",
  "domain": [10.0, 40.0],
  "value": [20.0, 25.0],
  "id": 10
}
```
:::

**Interpretación:** - `domain`: `[mínimo, máximo]` (rango continuo) -
`value`: `[mín_inicial, máx_inicial]` (subset del dominio) -
**Importante:** Valores se escalan ×1000 internamente - `20.0` → `20000`
(interno) - `25.5` → `25500` (interno)

##### [1.3.2.2.4]{.header-section-number} Tipo: **set** {#tipo-set number="1.3.2.2.4"}

**Descripción:** Variable de conjunto con elementos etiquetados

**Representación interna:** Integer (índice en el label map)

**Ejemplo:**

::: {#cb6 .sourceCode}
``` {.sourceCode .json}
{
  "name": "ZONA",
  "type": "set",
  "domain": ["NORTE", "SUR", "ESTE", "OESTE"],
  "value": ["NORTE", "SUR"],
  "id": 5
}
```
:::

**Interpretación:** - `domain`: Array de strings (etiquetas/labels) -
`value`: Subset del dominio - Internamente usa índices: NORTE=0, SUR=1,
ESTE=2, OESTE=3

**Label Map:**

    NORTE → 0
    SUR   → 1
    ESTE  → 2
    OESTE → 3

### [1.3.3]{.header-section-number} 2.3 Sección de Restricciones (Constraints) {#sección-de-restricciones-constraints number="1.3.3"}

#### [1.3.3.1]{.header-section-number} 2.3.1 Estructura de Constraint {#estructura-de-constraint number="1.3.3.1"}

::: {#cb8 .sourceCode}
``` {.sourceCode .json}
{
  "id": número_identificador,
  "expr": "expresión_textual",
  "root": id_nodo_raíz,
  "nodes": [ árbol_sintaxis_abstracta ],
  "var_refs": [ ids_variables_referenciadas ],
  "func_refs": [ ids_funciones_referenciadas ]
}
```
:::

#### [1.3.3.2]{.header-section-number} 2.3.2 Formato de Expresiones {#formato-de-expresiones number="1.3.3.2"}

Las expresiones en Gecode se almacenan de dos formas: 1. **Textual**
(campo `expr`): String legible 2. **AST** (campo `nodes`): Árbol de
sintaxis abstracta

**Ejemplo completo:**

::: {#cb9 .sourceCode}
``` {.sourceCode .json}
{
  "id": 10,
  "expr": "INTENTOS + NIVEL_ALERTA <= 4",
  "root": 4,
  "nodes": [
    {
      "id": 0,
      "type": "Variable",
      "name": "INTENTOS"
    },
    {
      "id": 1,
      "type": "Variable",
      "name": "NIVEL_ALERTA"
    },
    {
      "id": 2,
      "type": "Add",
      "left": 0,
      "right": 1
    },
    {
      "id": 3,
      "type": "Number",
      "value": 4
    },
    {
      "id": 4,
      "type": "LessEq",
      "left": 2,
      "right": 3
    }
  ],
  "var_refs": [8, 9],
  "func_refs": []
}
```
:::

#### [1.3.3.3]{.header-section-number} 2.3.3 Tipos de Nodos AST {#tipos-de-nodos-ast number="1.3.3.3"}

  Tipo             Descripción             Campos
  ---------------- ----------------------- ----------------------------------
  `Variable`       Variable del problema   `name`
  `Number`         Literal numérico        `value`
  `Equals`         Comparación `=`         `left`, `right`
  `NotEquals`      Comparación `!=`        `left`, `right`
  `Less`           Comparación `<`         `left`, `right`
  `Greater`        Comparación `>`         `left`, `right`
  `LessEq`         Comparación `<=`        `left`, `right`
  `GreaterEq`      Comparación `>=`        `left`, `right`
  `And`            Conjunción lógica       `left`, `right`
  `Or`             Disyunción lógica       `left`, `right`
  `Not`            Negación lógica         `left`
  `Add`            Suma aritmética         `left`, `right`
  `Subtract`       Resta aritmética        `left`, `right`
  `Multiply`       Multiplicación          `left`, `right`
  `Divide`         División                `left`, `right`
  `Negate`         Negación aritmética     `left`
  `In`             Pertenencia             `left`, `right`
  `Set`            Conjunto de valores     `elements[]`
  `Interval`       Rango numérico          `lo`, `hi`, `lo_open`, `hi_open`
  `FunctionCall`   Llamada a función       `name`, `args[]`

#### [1.3.3.4]{.header-section-number} 2.3.4 Operadores y Sintaxis de Expresiones {#operadores-y-sintaxis-de-expresiones number="1.3.3.4"}

**Operadores relacionales:**

    =    Igualdad
    !=   Desigualdad
    <    Menor que (estricto)
    >    Mayor que (estricto)
    <=   Menor o igual
    >=   Mayor o igual

**Operadores lógicos:**

    AND   Conjunción
    OR    Disyunción
    NOT   Negación

**Operadores aritméticos:**

    +    Suma
    -    Resta
    *    Multiplicación
    /    División

**Operadores de conjunto:**

    IN        Pertenencia
    {...}     Conjunto explícito
    [lo,hi]   Intervalo cerrado
    (lo,hi)   Intervalo abierto
    [lo,hi)   Intervalo semi-abierto

**Ejemplos de expresiones:**

    # Comparaciones simples
    PUERTA_ABIERTA = false
    ALARMA_ACTIVA = true
    TEMPERATURA_C > 20.0

    # Expresiones lógicas
    TARJETA_VALIDA = true AND HORARIO_LABORAL = true
    PUERTA_ABIERTA = false OR ALARMA_ACTIVA = true

    # Expresiones aritméticas
    INTENTOS + NIVEL_ALERTA <= 4
    TEMPERATURA_C * 1.8 + 32.0 >= 68.0

    # Pertenencia a conjuntos
    ZONA IN {NORTE, SUR, ESTE}
    PERFIL IN {EMPLEADO, SUPERVISOR, ADMIN}

    # Pertenencia a intervalos
    TEMPERATURA_C IN [18.0, 28.0]
    INTENTOS IN [0, 3]

    # Funciones
    abs(TEMPERATURA_C - 22.0) <= 3.0

### [1.3.4]{.header-section-number} 2.4 Sección de Funciones {#sección-de-funciones number="1.3.4"}

#### [1.3.4.1]{.header-section-number} 2.4.1 Estructura de Función {#estructura-de-función number="1.3.4.1"}

::: {#cb15 .sourceCode}
``` {.sourceCode .json}
{
  "name": "nombre_funcion",
  "params": ["param1", "param2"],
  "body": {
    "type": "Return",
    "expr": nodo_ast_expresion
  }
}
```
:::

**Ejemplo:**

::: {#cb16 .sourceCode}
``` {.sourceCode .json}
{
  "name": "es_supervisor",
  "params": ["perfil"],
  "body": {
    "type": "Return",
    "expr": {
      "type": "Or",
      "left": {
        "type": "Equals",
        "left": {"type": "Variable", "name": "perfil"},
        "right": {"type": "Variable", "name": "SUPERVISOR"}
      },
      "right": {
        "type": "Equals",
        "left": {"type": "Variable", "name": "perfil"},
        "right": {"type": "Variable", "name": "ADMIN"}
      }
    }
  }
}
```
:::

### [1.3.5]{.header-section-number} 2.5 Ejemplo Completo Gecode {#ejemplo-completo-gecode number="1.3.5"}

::: {#cb17 .sourceCode}
``` {.sourceCode .json}
{
  "variables": [
    {
      "name": "PUERTA_ABIERTA",
      "type": "boolean",
      "domain": [true, false],
      "value": [false],
      "id": 0
    },
    {
      "name": "ZONA",
      "type": "set",
      "domain": ["NORTE", "SUR", "ESTE", "OESTE"],
      "value": ["NORTE", "SUR"],
      "id": 1
    },
    {
      "name": "TEMPERATURA_C",
      "type": "numeric",
      "domain": [10.0, 40.0],
      "value": [20.0, 25.0],
      "id": 2
    },
    {
      "name": "INTENTOS",
      "type": "integer",
      "domain": [0, 1, 2, 3, 4, 5],
      "value": [0, 1],
      "id": 3
    }
  ],
  "functions": [],
  "constraints": [
    {
      "id": 0,
      "expr": "PUERTA_ABIERTA = false",
      "root": 2,
      "nodes": [
        {"id": 0, "type": "Variable", "name": "PUERTA_ABIERTA"},
        {"id": 1, "type": "Variable", "name": "FALSE"},
        {"id": 2, "type": "Equals", "left": 0, "right": 1}
      ],
      "var_refs": [0],
      "func_refs": []
    },
    {
      "id": 1,
      "expr": "ZONA IN {NORTE, SUR, ESTE}",
      "root": 5,
      "nodes": [
        {"id": 0, "type": "Variable", "name": "ZONA"},
        {"id": 1, "type": "Variable", "name": "NORTE"},
        {"id": 2, "type": "Variable", "name": "SUR"},
        {"id": 3, "type": "Variable", "name": "ESTE"},
        {"id": 4, "type": "Set", "elements": [1, 2, 3]},
        {"id": 5, "type": "In", "left": 0, "right": 4}
      ],
      "var_refs": [1],
      "func_refs": []
    },
    {
      "id": 2,
      "expr": "TEMPERATURA_C IN [18.0, 28.0]",
      "root": 4,
      "nodes": [
        {"id": 0, "type": "Variable", "name": "TEMPERATURA_C"},
        {"id": 1, "type": "Number", "value": 18},
        {"id": 2, "type": "Number", "value": 28},
        {"id": 3, "type": "Interval", "lo": 1, "hi": 2, "lo_open": false, "hi_open": false},
        {"id": 4, "type": "In", "left": 0, "right": 3}
      ],
      "var_refs": [2],
      "func_refs": []
    },
    {
      "id": 3,
      "expr": "INTENTOS + 1 <= 4",
      "root": 4,
      "nodes": [
        {"id": 0, "type": "Variable", "name": "INTENTOS"},
        {"id": 1, "type": "Number", "value": 1},
        {"id": 2, "type": "Add", "left": 0, "right": 1},
        {"id": 3, "type": "Number", "value": 4},
        {"id": 4, "type": "LessEq", "left": 2, "right": 3}
      ],
      "var_refs": [3],
      "func_refs": []
    }
  ]
}
```
:::

------------------------------------------------------------------------

## [1.4]{.header-section-number} 3. Sintaxis GNUBison {#sintaxis-gnubison number="1.4"}

### [1.4.1]{.header-section-number} 3.1 Estructura General {#estructura-general-1 number="1.4.1"}

::: {#cb18 .sourceCode}
``` {.sourceCode .json}
{
  "precision": número_decimales,
  "variables": [ ... ],
  "expresiones": [ ... ]
}
```
:::

### [1.4.2]{.header-section-number} 3.2 Sección de Variables {#sección-de-variables-1 number="1.4.2"}

#### [1.4.2.1]{.header-section-number} 3.2.1 Estructura de Variable {#estructura-de-variable-1 number="1.4.2.1"}

::: {#cb19 .sourceCode}
``` {.sourceCode .json}
{
  "nombre": "NOMBRE_VARIABLE",
  "tipo": "tipo",
  "domain": [ valores_posibles ],
  "value": valor_o_valores
}
```
:::

**Diferencias clave con Gecode:** - Campo `"nombre"` en lugar de
`"name"` (español vs inglés) - Campo `"tipo"` en lugar de `"type"` -
`value` puede ser un **valor único** (sin incertidumbre) o **array de
valores** (con incertidumbre) - No tiene campo `id`

#### [1.4.2.2]{.header-section-number} 3.2.2 Tipos de Variables {#tipos-de-variables-1 number="1.4.2.2"}

##### [1.4.2.2.1]{.header-section-number} Tipo: **logic** {#tipo-logic number="1.4.2.2.1"}

**Descripción:** Variable lógica (equivalente a `boolean` en Gecode)

**Valores permitidos:** `true`, `false`

**Ejemplo sin incertidumbre:**

::: {#cb20 .sourceCode}
``` {.sourceCode .json}
{
  "nombre": "activo",
  "tipo": "logic",
  "domain": [true, false],
  "value": true
}
```
:::

**Ejemplo con incertidumbre:**

::: {#cb21 .sourceCode}
``` {.sourceCode .json}
{
  "nombre": "activo",
  "tipo": "logic",
  "domain": [true, false],
  "value": [true, false]
}
```
:::

*Interpretación: La variable puede ser true O false*

##### [1.4.2.2.2]{.header-section-number} Tipo: **integer** {#tipo-integer-1 number="1.4.2.2.2"}

**Descripción:** Variable entera

**Ejemplo sin incertidumbre:**

::: {#cb22 .sourceCode}
``` {.sourceCode .json}
{
  "nombre": "nivel",
  "tipo": "integer",
  "domain": [1, 10],
  "value": 5
}
```
:::

**Ejemplo con incertidumbre:**

::: {#cb23 .sourceCode}
``` {.sourceCode .json}
{
  "nombre": "nivel",
  "tipo": "integer",
  "domain": [1, 10],
  "value": [3, 7]
}
```
:::

*Interpretación: El nivel puede ser 3 O 7 (no valores intermedios)*

##### [1.4.2.2.3]{.header-section-number} Tipo: **float** {#tipo-float number="1.4.2.2.3"}

**Descripción:** Variable de punto flotante

**Ejemplo:**

::: {#cb24 .sourceCode}
``` {.sourceCode .json}
{
  "nombre": "temperatura",
  "tipo": "float",
  "domain": [10.0, 40.0],
  "value": 20.5
}
```
:::

**Con incertidumbre:**

::: {#cb25 .sourceCode}
``` {.sourceCode .json}
{
  "nombre": "temperatura",
  "tipo": "float",
  "value": [18.0, 22.0, 25.0]
}
```
:::

##### [1.4.2.2.4]{.header-section-number} Tipo: **set** {#tipo-set-1 number="1.4.2.2.4"}

**Descripción:** Conjunto de elementos

**Ejemplo:**

::: {#cb26 .sourceCode}
``` {.sourceCode .json}
{
  "nombre": "zona",
  "tipo": "set",
  "domain": ["NORTE", "SUR", "ESTE", "OESTE"],
  "value": ["NORTE"]
}
```
:::

**Con incertidumbre:**

::: {#cb27 .sourceCode}
``` {.sourceCode .json}
{
  "nombre": "zona",
  "tipo": "set",
  "domain": ["NORTE", "SUR", "ESTE", "OESTE"],
  "value": ["NORTE", "SUR"]
}
```
:::

*Interpretación: La zona puede ser NORTE O SUR*

### [1.4.3]{.header-section-number} 3.3 Sección de Expresiones {#sección-de-expresiones number="1.4.3"}

#### [1.4.3.1]{.header-section-number} 3.3.1 Formato de Expresiones {#formato-de-expresiones-1 number="1.4.3.1"}

En GNUBison, las expresiones son **strings simples**, sin estructura
AST:

::: {#cb28 .sourceCode}
``` {.sourceCode .json}
{
  "expresiones": [
    "activo",
    "activo AND validado",
    "nivel > 5",
    "(activo OR validado) AND (nivel <= 8)"
  ]
}
```
:::

#### [1.4.3.2]{.header-section-number} 3.3.2 Sintaxis de Expresiones {#sintaxis-de-expresiones number="1.4.3.2"}

**Operadores lógicos:**

    AND        Conjunción
    OR         Disyunción
    NOT        Negación
    IMPLICA    Implicación lógica (A → B)

**Operadores relacionales:**

    =          Igualdad
    !=         Desigualdad
    <          Menor que
    >          Mayor que
    <=         Menor o igual
    >=         Mayor o igual

**Operadores aritméticos:**

    +          Suma
    -          Resta
    *          Multiplicación
    /          División

**Operadores de conjunto:**

    IN         Pertenencia
    {...}      Conjunto explícito
    [lo,hi]    Intervalo cerrado

**Funciones:**

    abs(x)     Valor absoluto
    sqrt(x)    Raíz cuadrada
    sin(x)     Seno
    cos(x)     Coseno

#### [1.4.3.3]{.header-section-number} 3.3.3 Ejemplos de Expresiones {#ejemplos-de-expresiones number="1.4.3.3"}

    # Expresiones simples
    activo
    validado
    NOT autorizado

    # Expresiones lógicas
    activo AND validado
    activo OR validado OR autorizado
    NOT(activo AND validado)

    # Implicación
    activo IMPLICA validado
    (activo AND conectado) IMPLICA (validado AND autorizado)

    # Comparaciones numéricas
    nivel > 5
    intentos < 4
    temperatura >= 18.0

    # Expresiones mixtas
    activo AND (nivel > 5)
    (validado OR autorizado) AND (intentos <= 3)

    # Pertenencia
    zona IN {NORTE, SUR}
    temperatura IN [18.0, 28.0]

### [1.4.4]{.header-section-number} 3.4 Formato de Salida {#formato-de-salida number="1.4.4"}

GNUBison genera un JSON con resultados de evaluación:

::: {#cb35 .sourceCode}
``` {.sourceCode .json}
{
  "archivo_entrada": "/path/to/input.json",
  "precision": 3,
  "factor": 1000,
  "variables": [
    {
      "nombre": "activo",
      "tipo": "logic",
      "dominio": [true, false],
      "valor": true
    }
  ],
  "expresiones": [
    {
      "expresion": "activo",
      "resultado": true
    },
    {
      "expresion": "activo AND validado",
      "resultado": false
    },
    {
      "expresion": "nivel > 5",
      "resultado": 0
    }
  ],
  "resumen": {
    "total_variables": 3,
    "total_expresiones": 3,
    "errores": 0,
    "valido": true
  }
}
```
:::

**Valores de `resultado`:** - `true` (1): La expresión es verdadera para
todos los valores posibles - `false` (0): La expresión es falsa para
todos los valores posibles - `0`: Indeterminado (verdadera en algunos
casos, falsa en otros)

### [1.4.5]{.header-section-number} 3.5 Ejemplo Completo GNUBison {#ejemplo-completo-gnubison number="1.4.5"}

::: {#cb36 .sourceCode}
``` {.sourceCode .json}
{
  "precision": 3,
  "variables": [
    {
      "nombre": "activo",
      "tipo": "logic",
      "domain": [true, false],
      "value": true
    },
    {
      "nombre": "validado",
      "tipo": "logic",
      "domain": [true, false],
      "value": [true, false]
    },
    {
      "nombre": "nivel",
      "tipo": "integer",
      "domain": [1, 10],
      "value": [3, 7]
    },
    {
      "nombre": "temperatura",
      "tipo": "float",
      "domain": [10.0, 40.0],
      "value": 22.5
    },
    {
      "nombre": "zona",
      "tipo": "set",
      "domain": ["NORTE", "SUR", "ESTE", "OESTE"],
      "value": ["NORTE"]
    }
  ],
  "expresiones": [
    "activo",
    "activo AND validado",
    "activo OR validado",
    "NOT activo",
    "nivel > 5",
    "temperatura >= 18.0 AND temperatura <= 28.0",
    "zona IN {NORTE, SUR, ESTE}",
    "(activo AND validado) IMPLICA (nivel > 5)"
  ]
}
```
:::

------------------------------------------------------------------------

## [1.5]{.header-section-number} 4. Comparación Detallada {#comparación-detallada number="1.5"}

### [1.5.1]{.header-section-number} 4.1 Tabla Comparativa: Campos de Variables {#tabla-comparativa-campos-de-variables number="1.5.1"}

  Aspecto             Gecode              GNUBison
  ------------------- ------------------- ------------
  **Campo nombre**    `"name"`            `"nombre"`
  **Campo tipo**      `"type"`            `"tipo"`
  **Campo dominio**   `"domain"`          `"domain"`
  **Campo valor**     `"value"`           `"value"`
  **Campo ID**        `"id"` (numérico)   No existe
  **Idioma campos**   Inglés              Español

### [1.5.2]{.header-section-number} 4.2 Tabla Comparativa: Tipos de Datos {#tabla-comparativa-tipos-de-datos number="1.5.2"}

  ------------------------------------------------------------------------------
  Gecode      GNUBison       Representación Interna             Notas
  ----------- -------------- ---------------------------------- ----------------
  `boolean`   `logic`        Integer 0/1                        Gecode usa 0/1,
                                                                GNUBison usa
                                                                true/false

  `integer`   `integer`      Integer nativo                     Idéntico

  `numeric`   `float`        Integer×1000 (Gecode), Float       Requiere
                             (GNUBison)                         transformación
                                                                ÷1000

  `set`       `set`          Integer índice (Gecode), String    Requiere label
                             array (GNUBison)                   map
  ------------------------------------------------------------------------------

### [1.5.3]{.header-section-number} 4.3 Tabla Comparativa: Valores {#tabla-comparativa-valores number="1.5.3"}

  -----------------------------------------------------------------------
  Aspecto                 Gecode               GNUBison
  ----------------------- -------------------- --------------------------
  **Formato**             Siempre array        Valor único o array

  **Incertidumbre**       No soporta           Soporta (array de valores)

  **Boolean**             `[true]` o `[false]` `true`, `false`, o
                                               `[true, false]`

  **Integer**             `[0, 1, 2]`          `5` o `[3, 7]`

  **Numeric/Float**       `[20.0, 25.0]`       `22.5` o `[18.0, 25.0]`

  **Set**                 `["NORTE", "SUR"]`   `["NORTE"]` o
                                               `["NORTE", "SUR"]`
  -----------------------------------------------------------------------

### [1.5.4]{.header-section-number} 4.4 Tabla Comparativa: Expresiones {#tabla-comparativa-expresiones number="1.5.4"}

  Aspecto            Gecode                  GNUBison
  ------------------ ----------------------- ---------------------------
  **Formato**        String + AST completo   Solo string
  **Operador AND**   `AND`                   `AND`
  **Operador OR**    `OR`                    `OR`
  **Operador NOT**   `NOT`                   `NOT`
  **Implicación**    No nativo               `IMPLICA`
  **Igualdad**       `=`                     `=`
  **Pertenencia**    `IN`                    `IN`
  **Funciones**      Limitado                abs, sqrt, sin, cos, etc.

### [1.5.5]{.header-section-number} 4.5 Tabla Comparativa: Estructura General {#tabla-comparativa-estructura-general number="1.5.5"}

  -----------------------------------------------------------------------
  Aspecto                 Gecode               GNUBison
  ----------------------- -------------------- --------------------------
  **Secciones**           variables,           variables, expresiones
                          functions,           
                          constraints          

  **AST**                 Sí (completo)        No

  **Funciones**           Definibles por       Built-in
                          usuario              

  **Complejidad**         Alta (AST detallado) Baja (strings simples)

  **Propósito**           Definir CSP completo Evaluar expresiones
  -----------------------------------------------------------------------

------------------------------------------------------------------------

## [1.6]{.header-section-number} 5. Gramática Formal {#gramática-formal number="1.6"}

### [1.6.1]{.header-section-number} 5.1 Gramática Gecode (EBNF) {#gramática-gecode-ebnf number="1.6.1"}

``` ebnf
(* Gramática del formato JSON de Gecode *)

CSPDocument = "{" VariablesSection "," [FunctionsSection ","] ConstraintsSection "}" ;

(* ────────────────────────────────────────────────────────── *)
(* Variables *)
(* ────────────────────────────────────────────────────────── *)

VariablesSection = '"variables":' "[" [VariableList] "]" ;

VariableList = Variable { "," Variable } ;

Variable = "{"
    '"name":' String ","
    '"type":' VariableType ","
    '"domain":' Domain ","
    '"value":' ValueSpec ","
    '"id":' Number
    "}" ;

VariableType = '"boolean"' | '"integer"' | '"numeric"' | '"set"' ;

Domain = "[" ValueList "]" ;

ValueList = Value { "," Value } ;

Value = Number | String | Boolean ;

ValueSpec = "[" ValueList "]" ;

(* ────────────────────────────────────────────────────────── *)
(* Functions *)
(* ────────────────────────────────────────────────────────── *)

FunctionsSection = '"functions":' "[" [FunctionList] "]" ;

FunctionList = Function { "," Function } ;

Function = "{"
    '"name":' String ","
    '"params":' "[" [ParamList] "]" ","
    '"body":' FunctionBody
    "}" ;

ParamList = String { "," String } ;

FunctionBody = "{"
    '"type": "Return"' ","
    '"expr":' ASTNode
    "}" ;

(* ────────────────────────────────────────────────────────── *)
(* Constraints *)
(* ────────────────────────────────────────────────────────── *)

ConstraintsSection = '"constraints":' "[" [ConstraintList] "]" ;

ConstraintList = Constraint { "," Constraint } ;

Constraint = "{"
    '"id":' Number ","
    '"expr":' String ","
    '"root":' Number ","
    '"nodes":' "[" [ASTNodeList] "]" ","
    '"var_refs":' "[" [NumberList] "]" ","
    '"func_refs":' "[" [NumberList] "]"
    "}" ;

ASTNodeList = ASTNode { "," ASTNode } ;

ASTNode = "{"
    '"id":' Number ","
    '"type":' NodeType ","
    [NodeFields]
    "}" ;

NodeType = '"Variable"' | '"Number"' | '"Equals"' | '"NotEquals"' |
           '"Less"' | '"Greater"' | '"LessEq"' | '"GreaterEq"' |
           '"And"' | '"Or"' | '"Not"' |
           '"Add"' | '"Subtract"' | '"Multiply"' | '"Divide"' |
           '"Negate"' | '"In"' | '"Set"' | '"Interval"' | '"FunctionCall"' ;

NodeFields = VariableField | NumberField | BinaryOpFields |
             UnaryOpField | SetFields | IntervalFields | FunctionFields ;

VariableField = '"name":' String ;

NumberField = '"value":' Number ;

BinaryOpFields = '"left":' Number "," '"right":' Number ;

UnaryOpField = '"left":' Number ;

SetFields = '"elements":' "[" [NumberList] "]" ;

IntervalFields = '"lo":' Number "," '"hi":' Number ","
                 '"lo_open":' Boolean "," '"hi_open":' Boolean ;

FunctionFields = '"name":' String "," '"args":' "[" [NumberList] "]" ;

NumberList = Number { "," Number } ;

(* ────────────────────────────────────────────────────────── *)
(* Primitivos *)
(* ────────────────────────────────────────────────────────── *)

String = '"' { character } '"' ;

Number = ["-"] digit { digit } ["." digit { digit }] ;

Boolean = "true" | "false" ;

digit = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" ;

character = (* cualquier carácter Unicode válido *) ;
```

### [1.6.2]{.header-section-number} 5.2 Gramática GNUBison (EBNF) {#gramática-gnubison-ebnf number="1.6.2"}

``` ebnf
(* Gramática del formato JSON de GNUBison *)

BisonDocument = "{" PrecisionField "," VariablesSection "," ExpresionesSection "}" ;

(* ────────────────────────────────────────────────────────── *)
(* Campos principales *)
(* ────────────────────────────────────────────────────────── *)

PrecisionField = '"precision":' Number ;

(* ────────────────────────────────────────────────────────── *)
(* Variables *)
(* ────────────────────────────────────────────────────────── *)

VariablesSection = '"variables":' "[" [VariableList] "]" ;

VariableList = Variable { "," Variable } ;

Variable = "{"
    '"nombre":' String ","
    '"tipo":' BisonType ","
    ['"domain":' Domain ","]
    '"value":' BisonValue
    "}" ;

BisonType = '"logic"' | '"integer"' | '"float"' | '"set"' ;

Domain = "[" ValueList "]" ;

ValueList = Value { "," Value } ;

Value = Number | String | Boolean ;

BisonValue = SingleValue | "[" ValueList "]" ;

SingleValue = Number | String | Boolean | "[" StringList "]" ;

StringList = String { "," String } ;

(* ────────────────────────────────────────────────────────── *)
(* Expresiones *)
(* ────────────────────────────────────────────────────────── *)

ExpresionesSection = '"expresiones":' "[" [ExpressionList] "]" ;

ExpressionList = Expression { "," Expression } ;

Expression = String ;  (* Expresión como string simple *)

(* ────────────────────────────────────────────────────────── *)
(* Gramática de expresiones (dentro del string) *)
(* ────────────────────────────────────────────────────────── *)

(* Esta es la gramática del lenguaje de expresiones *)

ExprString = LogicExpr ;

LogicExpr = CompExpr { ("AND" | "OR" | "IMPLICA") CompExpr } ;

CompExpr = ArithExpr [("=" | "!=" | "<" | ">" | "<=" | ">=") ArithExpr] |
           ArithExpr "IN" SetExpr ;

ArithExpr = Term { ("+" | "-") Term } ;

Term = Factor { ("*" | "/") Factor } ;

Factor = Number |
         Identifier |
         "NOT" Factor |
         FunctionCall |
         "(" LogicExpr ")" ;

FunctionCall = Identifier "(" [ArgList] ")" ;

ArgList = LogicExpr { "," LogicExpr } ;

SetExpr = "{" IdentifierList "}" |
          "[" Number "," Number "]" ;

IdentifierList = Identifier { "," Identifier } ;

Identifier = letter { letter | digit | "_" } ;

letter = "A" | "B" | ... | "Z" | "a" | "b" | ... | "z" ;

digit = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" ;

(* ────────────────────────────────────────────────────────── *)
(* Primitivos *)
(* ────────────────────────────────────────────────────────── *)

String = '"' { character } '"' ;

Number = ["-"] digit { digit } ["." digit { digit }] ;

Boolean = "true" | "false" ;

character = (* cualquier carácter Unicode válido, excepto " sin escapar *) ;
```

------------------------------------------------------------------------

## [1.7]{.header-section-number} 6. Transformaciones {#transformaciones number="1.7"}

### [1.7.1]{.header-section-number} 6.1 Transformación Gecode → GNUBison {#transformación-gecode-gnubison number="1.7.1"}

#### [1.7.1.1]{.header-section-number} 6.1.1 Transformación de Campos {#transformación-de-campos number="1.7.1.1"}

    Gecode               GNUBison
    ─────────────────────────────────
    "name"          →    "nombre"
    "type"          →    "tipo"
    "domain"        →    "domain"  (igual)
    "value"         →    "value"   (igual, pero formato diferente)
    "id"            →    (se omite)

#### [1.7.1.2]{.header-section-number} 6.1.2 Transformación de Tipos {#transformación-de-tipos number="1.7.1.2"}

    Gecode          GNUBison        Transformación
    ────────────────────────────────────────────────────────────
    boolean    →    logic           Cambio de nombre
    integer    →    integer         Sin cambios
    numeric    →    float           Cambio + escala ÷1000
    set        →    set             Sin cambios (pero valores cambian)

#### [1.7.1.3]{.header-section-number} 6.1.3 Transformación de Valores {#transformación-de-valores number="1.7.1.3"}

**Boolean:**

    Gecode: valor interno = 0 o 1
    GNUBison: value = false o true

    Transformación:
      0 → false
      1 → true

**Numeric/Float:**

    Gecode: valor interno escalado ×1000
    GNUBison: valor float real

    Transformación:
      20099 → 20.099
      25500 → 25.5

    Fórmula: gnubison_value = gecode_value / 1000.0

**Set:**

    Gecode: valor = índice numérico (0, 1, 2, ...)
    GNUBison: value = array de strings

    Transformación con Label Map:
      Gecode: ZONA = 0
      LabelMap: 0 → "NORTE"
      GNUBison: {"nombre": "ZONA", "value": ["NORTE"]}

**Integer:**

    Sin transformación:
      Gecode: 5 → GNUBison: 5

#### [1.7.1.4]{.header-section-number} 6.1.4 Ejemplo Completo de Transformación {#ejemplo-completo-de-transformación number="1.7.1.4"}

**Entrada Gecode (solución):**

    PUERTA_ABIERTA=0 ZONA=0 TEMPERATURA_C=20099 INTENTOS=2

**Datos del grafo Gecode:**

::: {#cb46 .sourceCode}
``` {.sourceCode .json}
{
  "variables": [
    {"name": "PUERTA_ABIERTA", "type": "boolean", ...},
    {"name": "ZONA", "type": "set", "domain": ["NORTE", "SUR", "ESTE"], ...},
    {"name": "TEMPERATURA_C", "type": "numeric", ...},
    {"name": "INTENTOS", "type": "integer", ...}
  ]
}
```
:::

**Label Map:**

    ZONA[0] = "NORTE"
    ZONA[1] = "SUR"
    ZONA[2] = "ESTE"

**Salida GNUBison:**

::: {#cb48 .sourceCode}
``` {.sourceCode .json}
{
  "precision": 3,
  "variables": [
    {
      "nombre": "PUERTA_ABIERTA",
      "tipo": "logic",
      "value": false
    },
    {
      "nombre": "ZONA",
      "tipo": "set",
      "value": ["NORTE"]
    },
    {
      "nombre": "TEMPERATURA_C",
      "tipo": "float",
      "value": 20.099
    },
    {
      "nombre": "INTENTOS",
      "tipo": "integer",
      "value": 2
    }
  ],
  "expresiones": [
    "PUERTA_ABIERTA = false",
    "ZONA IN {NORTE, SUR, ESTE}",
    "TEMPERATURA_C IN [18.0, 28.0]",
    "INTENTOS <= 3"
  ]
}
```
:::

### [1.7.2]{.header-section-number} 6.2 Algoritmo de Transformación {#algoritmo-de-transformación number="1.7.2"}

::: {#cb49 .sourceCode}
``` {.sourceCode .pascal}
function TransformGecodeSolutionToGNUBison(
  solution: GecodeSolution,
  graphData: GecodeGraphData
): GNUBisonJSON;
begin
  result.precision := 3;
  result.variables := [];

  for each var in solution do
    bisonVar.nombre := graphData.getVariableName(var.index);
    geType := graphData.getVariableType(var.index);

    case geType of
      'boolean':
        bisonVar.tipo := 'logic';
        bisonVar.value := (var.value = 1) ? true : false;

      'integer':
        bisonVar.tipo := 'integer';
        bisonVar.value := var.value;

      'numeric':
        bisonVar.tipo := 'float';
        bisonVar.value := var.value / 1000.0;

      'set':
        bisonVar.tipo := 'set';
        label := graphData.getLabelForIndex(var.index, var.value);
        bisonVar.value := [label];
    end;

    result.variables.append(bisonVar);
  end;

  result.expresiones := graphData.getAllExpressions();

  return result;
end;
```
:::

------------------------------------------------------------------------

## [1.8]{.header-section-number} 7. Ejemplos Completos {#ejemplos-completos number="1.8"}

### [1.8.1]{.header-section-number} 7.1 Ejemplo: Sistema de Control de Acceso {#ejemplo-sistema-de-control-de-acceso number="1.8.1"}

#### [1.8.1.1]{.header-section-number} 7.1.1 Versión Gecode {#versión-gecode number="1.8.1.1"}

::: {#cb50 .sourceCode}
``` {.sourceCode .json}
{
  "variables": [
    {
      "name": "PUERTA_ABIERTA",
      "type": "boolean",
      "domain": [true, false],
      "value": [false],
      "id": 0
    },
    {
      "name": "ALARMA_ACTIVA",
      "type": "boolean",
      "domain": [true, false],
      "value": [false],
      "id": 1
    },
    {
      "name": "TARJETA_VALIDA",
      "type": "boolean",
      "domain": [true, false],
      "value": [true],
      "id": 2
    },
    {
      "name": "HORARIO_LABORAL",
      "type": "boolean",
      "domain": [true, false],
      "value": [true],
      "id": 3
    },
    {
      "name": "PERFIL",
      "type": "set",
      "domain": ["VISITANTE", "EMPLEADO", "SUPERVISOR", "ADMIN"],
      "value": ["EMPLEADO"],
      "id": 4
    },
    {
      "name": "INTENTOS",
      "type": "integer",
      "domain": [0, 1, 2, 3, 4, 5],
      "value": [0, 1],
      "id": 5
    }
  ],
  "functions": [],
  "constraints": [
    {
      "id": 0,
      "expr": "PUERTA_ABIERTA = false",
      "root": 2,
      "nodes": [
        {"id": 0, "type": "Variable", "name": "PUERTA_ABIERTA"},
        {"id": 1, "type": "Variable", "name": "FALSE"},
        {"id": 2, "type": "Equals", "left": 0, "right": 1}
      ],
      "var_refs": [0],
      "func_refs": []
    },
    {
      "id": 1,
      "expr": "ALARMA_ACTIVA = false",
      "root": 2,
      "nodes": [
        {"id": 0, "type": "Variable", "name": "ALARMA_ACTIVA"},
        {"id": 1, "type": "Variable", "name": "FALSE"},
        {"id": 2, "type": "Equals", "left": 0, "right": 1}
      ],
      "var_refs": [1],
      "func_refs": []
    },
    {
      "id": 2,
      "expr": "TARJETA_VALIDA = true AND HORARIO_LABORAL = true",
      "root": 6,
      "nodes": [
        {"id": 0, "type": "Variable", "name": "TARJETA_VALIDA"},
        {"id": 1, "type": "Variable", "name": "TRUE"},
        {"id": 2, "type": "Equals", "left": 0, "right": 1},
        {"id": 3, "type": "Variable", "name": "HORARIO_LABORAL"},
        {"id": 4, "type": "Variable", "name": "TRUE"},
        {"id": 5, "type": "Equals", "left": 3, "right": 4},
        {"id": 6, "type": "And", "left": 2, "right": 5}
      ],
      "var_refs": [2, 3],
      "func_refs": []
    },
    {
      "id": 3,
      "expr": "PERFIL IN {EMPLEADO, SUPERVISOR, ADMIN}",
      "root": 5,
      "nodes": [
        {"id": 0, "type": "Variable", "name": "PERFIL"},
        {"id": 1, "type": "Variable", "name": "EMPLEADO"},
        {"id": 2, "type": "Variable", "name": "SUPERVISOR"},
        {"id": 3, "type": "Variable", "name": "ADMIN"},
        {"id": 4, "type": "Set", "elements": [1, 2, 3]},
        {"id": 5, "type": "In", "left": 0, "right": 4}
      ],
      "var_refs": [4],
      "func_refs": []
    },
    {
      "id": 4,
      "expr": "INTENTOS IN [0, 3]",
      "root": 4,
      "nodes": [
        {"id": 0, "type": "Variable", "name": "INTENTOS"},
        {"id": 1, "type": "Number", "value": 0},
        {"id": 2, "type": "Number", "value": 3},
        {"id": 3, "type": "Interval", "lo": 1, "hi": 2, "lo_open": false, "hi_open": false},
        {"id": 4, "type": "In", "left": 0, "right": 3}
      ],
      "var_refs": [5],
      "func_refs": []
    }
  ]
}
```
:::

#### [1.8.1.2]{.header-section-number} 7.1.2 Versión GNUBison (Solución Concreta) {#versión-gnubison-solución-concreta number="1.8.1.2"}

::: {#cb51 .sourceCode}
``` {.sourceCode .json}
{
  "precision": 3,
  "variables": [
    {
      "nombre": "PUERTA_ABIERTA",
      "tipo": "logic",
      "value": false
    },
    {
      "nombre": "ALARMA_ACTIVA",
      "tipo": "logic",
      "value": false
    },
    {
      "nombre": "TARJETA_VALIDA",
      "tipo": "logic",
      "value": true
    },
    {
      "nombre": "HORARIO_LABORAL",
      "tipo": "logic",
      "value": true
    },
    {
      "nombre": "PERFIL",
      "tipo": "set",
      "value": ["EMPLEADO"]
    },
    {
      "nombre": "INTENTOS",
      "tipo": "integer",
      "value": 0
    }
  ],
  "expresiones": [
    "PUERTA_ABIERTA = false",
    "ALARMA_ACTIVA = false",
    "TARJETA_VALIDA = true AND HORARIO_LABORAL = true",
    "PERFIL IN {EMPLEADO, SUPERVISOR, ADMIN}",
    "INTENTOS IN [0, 3]"
  ]
}
```
:::

#### [1.8.1.3]{.header-section-number} 7.1.3 Versión GNUBison (Con Incertidumbre) {#versión-gnubison-con-incertidumbre number="1.8.1.3"}

::: {#cb52 .sourceCode}
``` {.sourceCode .json}
{
  "precision": 3,
  "variables": [
    {
      "nombre": "PUERTA_ABIERTA",
      "tipo": "logic",
      "value": [true, false]
    },
    {
      "nombre": "ALARMA_ACTIVA",
      "tipo": "logic",
      "value": [true, false]
    },
    {
      "nombre": "TARJETA_VALIDA",
      "tipo": "logic",
      "value": true
    },
    {
      "nombre": "HORARIO_LABORAL",
      "tipo": "logic",
      "value": true
    },
    {
      "nombre": "PERFIL",
      "tipo": "set",
      "value": ["EMPLEADO", "SUPERVISOR"]
    },
    {
      "nombre": "INTENTOS",
      "tipo": "integer",
      "value": [0, 1, 2]
    }
  ],
  "expresiones": [
    "TARJETA_VALIDA = true AND HORARIO_LABORAL = true",
    "PERFIL IN {EMPLEADO, SUPERVISOR, ADMIN}",
    "INTENTOS IN [0, 3]",
    "(PUERTA_ABIERTA = true) IMPLICA (ALARMA_ACTIVA = false)"
  ]
}
```
:::

### [1.8.2]{.header-section-number} 7.2 Ejemplo: Sistema de Monitoreo de Temperatura {#ejemplo-sistema-de-monitoreo-de-temperatura number="1.8.2"}

#### [1.8.2.1]{.header-section-number} 7.2.1 Versión Gecode {#versión-gecode-1 number="1.8.2.1"}

::: {#cb53 .sourceCode}
``` {.sourceCode .json}
{
  "variables": [
    {
      "name": "SENSOR_ACTIVO",
      "type": "boolean",
      "domain": [true, false],
      "value": [true],
      "id": 0
    },
    {
      "name": "TEMPERATURA_C",
      "type": "numeric",
      "domain": [0.0, 50.0],
      "value": [18.0, 28.0],
      "id": 1
    },
    {
      "name": "VENTILADOR_ON",
      "type": "boolean",
      "domain": [true, false],
      "value": [true, false],
      "id": 2
    },
    {
      "name": "NIVEL_POTENCIA",
      "type": "integer",
      "domain": [0, 1, 2, 3],
      "value": [0, 1, 2, 3],
      "id": 3
    }
  ],
  "functions": [],
  "constraints": [
    {
      "id": 0,
      "expr": "SENSOR_ACTIVO = true",
      "root": 2,
      "nodes": [
        {"id": 0, "type": "Variable", "name": "SENSOR_ACTIVO"},
        {"id": 1, "type": "Variable", "name": "TRUE"},
        {"id": 2, "type": "Equals", "left": 0, "right": 1}
      ],
      "var_refs": [0],
      "func_refs": []
    },
    {
      "id": 1,
      "expr": "TEMPERATURA_C IN [18.0, 28.0]",
      "root": 4,
      "nodes": [
        {"id": 0, "type": "Variable", "name": "TEMPERATURA_C"},
        {"id": 1, "type": "Number", "value": 18.0},
        {"id": 2, "type": "Number", "value": 28.0},
        {"id": 3, "type": "Interval", "lo": 1, "hi": 2, "lo_open": false, "hi_open": false},
        {"id": 4, "type": "In", "left": 0, "right": 3}
      ],
      "var_refs": [1],
      "func_refs": []
    },
    {
      "id": 2,
      "expr": "TEMPERATURA_C > 25.0 = VENTILADOR_ON = true",
      "root": 6,
      "nodes": [
        {"id": 0, "type": "Variable", "name": "TEMPERATURA_C"},
        {"id": 1, "type": "Number", "value": 25.0},
        {"id": 2, "type": "Greater", "left": 0, "right": 1},
        {"id": 3, "type": "Variable", "name": "VENTILADOR_ON"},
        {"id": 4, "type": "Variable", "name": "TRUE"},
        {"id": 5, "type": "Equals", "left": 3, "right": 4},
        {"id": 6, "type": "Equals", "left": 2, "right": 5}
      ],
      "var_refs": [1, 2],
      "func_refs": []
    }
  ]
}
```
:::

#### [1.8.2.2]{.header-section-number} 7.2.2 Versión GNUBison {#versión-gnubison number="1.8.2.2"}

::: {#cb54 .sourceCode}
``` {.sourceCode .json}
{
  "precision": 3,
  "variables": [
    {
      "nombre": "SENSOR_ACTIVO",
      "tipo": "logic",
      "value": true
    },
    {
      "nombre": "TEMPERATURA_C",
      "tipo": "float",
      "value": 26.5
    },
    {
      "nombre": "VENTILADOR_ON",
      "tipo": "logic",
      "value": true
    },
    {
      "nombre": "NIVEL_POTENCIA",
      "tipo": "integer",
      "value": 2
    }
  ],
  "expresiones": [
    "SENSOR_ACTIVO = true",
    "TEMPERATURA_C IN [18.0, 28.0]",
    "(TEMPERATURA_C > 25.0) IMPLICA (VENTILADOR_ON = true)",
    "(VENTILADOR_ON = true) IMPLICA (NIVEL_POTENCIA > 0)"
  ]
}
```
:::

------------------------------------------------------------------------

## [1.9]{.header-section-number} 8. Referencia Rápida {#referencia-rápida number="1.9"}

### [1.9.1]{.header-section-number} 8.1 Gecode - Cheat Sheet {#gecode---cheat-sheet number="1.9.1"}

**Tipos de Variables:**

    boolean  →  IntVar [0,1]
    integer  →  IntVar [min,max] + conjunto discreto
    numeric  →  IntVar × 1000
    set      →  IntVar [0,n-1] + label map

**Estructura AST:**

::: {#cb56 .sourceCode}
``` {.sourceCode .json}
{
  "id": N,
  "type": "TipoNodo",
  "left": id_izq,     // para operadores binarios
  "right": id_der,    // para operadores binarios
  "name": "VAR",      // para Variable
  "value": número,    // para Number
  "elements": [...]   // para Set
}
```
:::

**Operadores Comunes:**

    Comparación:  Equals, NotEquals, Less, Greater, LessEq, GreaterEq
    Lógica:       And, Or, Not
    Aritmética:   Add, Subtract, Multiply, Divide, Negate
    Conjunto:     In, Set, Interval

### [1.9.2]{.header-section-number} 8.2 GNUBison - Cheat Sheet {#gnubison---cheat-sheet number="1.9.2"}

**Tipos de Variables:**

    logic    →  true/false o [true, false]
    integer  →  número o [n1, n2, ...]
    float    →  número o [f1, f2, ...]
    set      →  ["label"] o ["l1", "l2", ...]

**Operadores:**

    Lógicos:      AND, OR, NOT, IMPLICA
    Relacionales: =, !=, <, >, <=, >=
    Aritméticos:  +, -, *, /
    Conjunto:     IN, {...}, [lo, hi]

**Funciones Built-in:**

    abs(x)    sin(x)    cos(x)    tan(x)
    sqrt(x)   exp(x)    log(x)    ln(x)

### [1.9.3]{.header-section-number} 8.3 Tabla de Transformación Rápida {#tabla-de-transformación-rápida number="1.9.3"}

  De (Gecode)             A (GNUBison)        Transformación
  ----------------------- ------------------- ------------------------
  `"name"`                `"nombre"`          Renombrar campo
  `"type": "boolean"`     `"tipo": "logic"`   Cambiar tipo
  `"type": "numeric"`     `"tipo": "float"`   Cambiar tipo
  `valor_int` (boolean)   `true/false`        0→false, 1→true
  `valor_int` (numeric)   `valor_float`       ÷1000
  `índice` (set)          `["label"]`         Lookup en LabelMap
  `[valores]` (value)     `valor` único       Extraer único de array

------------------------------------------------------------------------

## [1.10]{.header-section-number} 9. Apéndices {#apéndices number="1.10"}

### [1.10.1]{.header-section-number} 9.1 Apéndice A: Operadores Completos {#apéndice-a-operadores-completos number="1.10.1"}

#### [1.10.1.1]{.header-section-number} Gecode {#gecode number="1.10.1.1"}

  Operador AST     Sintaxis Textual   Descripción           Ejemplo
  ---------------- ------------------ --------------------- ----------------
  `Equals`         `=`                Igualdad              `X = 5`
  `NotEquals`      `!=`, `/=`         Desigualdad           `X != 0`
  `Less`           `<`                Menor estricto        `X < 10`
  `Greater`        `>`                Mayor estricto        `X > 0`
  `LessEq`         `<=`               Menor o igual         `X <= 100`
  `GreaterEq`      `>=`               Mayor o igual         `X >= 18`
  `And`            `AND`              Conjunción            `A AND B`
  `Or`             `OR`               Disyunción            `A OR B`
  `Not`            `NOT`              Negación              `NOT A`
  `Add`            `+`                Suma                  `X + Y`
  `Subtract`       `-`                Resta                 `X - Y`
  `Multiply`       `*`                Multiplicación        `X * 2`
  `Divide`         `/`                División              `X / 3`
  `Negate`         `-` (unario)       Negación aritmética   `-X`
  `In`             `IN`               Pertenencia           `X IN {1,2,3}`
  `FunctionCall`   `func(args)`       Llamada función       `abs(X)`

#### [1.10.1.2]{.header-section-number} GNUBison {#gnubison number="1.10.1.2"}

  Operador               Descripción                Ejemplo         Precedencia
  ---------------------- -------------------------- --------------- --------------
  `IMPLICA`              Implicación lógica         `A IMPLICA B`   1 (más baja)
  `OR`                   Disyunción                 `A OR B`        2
  `AND`                  Conjunción                 `A AND B`       3
  `NOT`                  Negación                   `NOT A`         4
  `=`, `!=`              Igualdad, desigualdad      `X = 5`         5
  `<`, `>`, `<=`, `>=`   Comparación                `X > 0`         5
  `IN`                   Pertenencia                `X IN {1,2}`    5
  `+`, `-`               Suma, resta                `X + Y`         6
  `*`, `/`               Multiplicación, división   `X * 2`         7
  `-` (unario)           Negación aritmética        `-X`            8 (más alta)

### [1.10.2]{.header-section-number} 9.2 Apéndice B: Funciones Disponibles {#apéndice-b-funciones-disponibles number="1.10.2"}

#### [1.10.2.1]{.header-section-number} GNUBison (Built-in) {#gnubison-built-in number="1.10.2.1"}

  Función     Descripción         Dominio        Ejemplo
  ----------- ------------------- -------------- ------------------
  `abs(x)`    Valor absoluto      ℝ → ℝ⁺         `abs(-5) = 5`
  `sqrt(x)`   Raíz cuadrada       ℝ⁺ → ℝ⁺        `sqrt(9) = 3`
  `sin(x)`    Seno                ℝ → \[-1,1\]   `sin(0) = 0`
  `cos(x)`    Coseno              ℝ → \[-1,1\]   `cos(0) = 1`
  `tan(x)`    Tangente            ℝ → ℝ          `tan(0) = 0`
  `exp(x)`    Exponencial (eˣ)    ℝ → ℝ⁺         `exp(1) ≈ 2.718`
  `log(x)`    Logaritmo base 10   ℝ⁺ → ℝ         `log(100) = 2`
  `ln(x)`     Logaritmo natural   ℝ⁺ → ℝ         `ln(e) = 1`

#### [1.10.2.2]{.header-section-number} Gecode (User-Defined) {#gecode-user-defined number="1.10.2.2"}

Gecode soporta funciones definidas por el usuario mediante la sección
`functions`:

::: {#cb61 .sourceCode}
``` {.sourceCode .json}
{
  "name": "es_adulto",
  "params": ["edad"],
  "body": {
    "type": "Return",
    "expr": {
      "type": "GreaterEq",
      "left": {"type": "Variable", "name": "edad"},
      "right": {"type": "Number", "value": 18}
    }
  }
}
```
:::

### [1.10.3]{.header-section-number} 9.3 Apéndice C: Códigos de Error {#apéndice-c-códigos-de-error number="1.10.3"}

#### [1.10.3.1]{.header-section-number} Gecode {#gecode-1 number="1.10.3.1"}

  Código                 Descripción
  ---------------------- -------------------------------
  `ERR_SYNTAX`           Error de sintaxis en JSON
  `ERR_TYPE_MISMATCH`    Tipo de variable incompatible
  `ERR_UNDEFINED_VAR`    Variable no definida
  `ERR_UNDEFINED_FUNC`   Función no definida
  `ERR_INVALID_DOMAIN`   Dominio inválido
  `ERR_AST_INVALID`      Nodo AST malformado

#### [1.10.3.2]{.header-section-number} GNUBison {#gnubison-1 number="1.10.3.2"}

  Campo Resumen     Descripción
  ----------------- ---------------------------------
  `errores: 0`      Sin errores
  `errores: N`      N expresiones con error
  `valido: true`    Todas las expresiones válidas
  `valido: false`   Al menos una expresión inválida

### [1.10.4]{.header-section-number} 9.4 Apéndice D: Herramientas de Conversión {#apéndice-d-herramientas-de-conversión number="1.10.4"}

#### [1.10.4.1]{.header-section-number} Convertir Markdown a PDF {#convertir-markdown-a-pdf number="1.10.4.1"}

::: {#cb62 .sourceCode}
``` {.sourceCode .bash}
# Usando pandoc
pandoc Comparacion_Sintaxis_Gecode_GNUBison.md \
       -o Comparacion_Sintaxis.pdf \
       --pdf-engine=xelatex \
       --toc \
       --toc-depth=3 \
       --number-sections \
       -V geometry:margin=1in \
       -V fontsize=11pt

# Usando wkhtmltopdf (via HTML)
markdown Comparacion_Sintaxis_Gecode_GNUBison.md | \
  wkhtmltopdf - Comparacion_Sintaxis.pdf
```
:::

### [1.10.5]{.header-section-number} 9.5 Apéndice E: Recursos Adicionales {#apéndice-e-recursos-adicionales number="1.10.5"}

**Documentación Gecode:** - `docs/pipeline.txt` - Guía completa del
pipeline - `docs/VerifyWithBison.txt` - Documentación del verificador -
`README.md` - Guía de inicio rápido

**Documentación GNUBison:** - `/home/rodo/GNUBison/README.md` - Manual
de GNUBison - `/home/rodo/GNUBison/tests/` - Ejemplos de uso

**Ejemplos:** - `gecode/ejemplos/Json_input_*.json` - Entradas de
ejemplo - `gecode/ejemplos/Json_output_*.json` - Grafos AST de ejemplo -
`GNUBison/tests/test_*.json` - Casos de prueba

------------------------------------------------------------------------

## [1.11]{.header-section-number} Glosario {#glosario number="1.11"}

**AST (Abstract Syntax Tree):** Árbol de sintaxis abstracta.
Representación en forma de árbol de la estructura sintáctica de una
expresión.

**Boolean:** Tipo de dato lógico con dos valores posibles: verdadero
(true) o falso (false).

**Constraint:** Restricción o condición que debe satisfacerse en un
problema CSP.

**CSP (Constraint Satisfaction Problem):** Problema de satisfacción de
restricciones. Problema definido por variables, dominios y
restricciones.

**Domain:** Conjunto de valores posibles que puede tomar una variable.

**Incertidumbre:** Capacidad de representar múltiples valores posibles
simultáneamente para una variable.

**Label Map:** Mapeo entre índices numéricos y etiquetas textuales para
variables de tipo set.

**Node:** Nodo en un árbol AST que representa un operador, variable o
literal.

**Numeric:** Tipo de dato de punto flotante escalado internamente como
entero ×1000.

**Set:** Tipo de dato que representa un conjunto de elementos
etiquetados.

**Solver:** Programa que encuentra soluciones a problemas CSP.

------------------------------------------------------------------------

**Fin del Documento**

------------------------------------------------------------------------

*Documento generado para el proyecto Pipeline CSP* *Gecode + GNUBison
Integration* *Versión 1.0 - Febrero 2026*
