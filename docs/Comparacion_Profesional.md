---
title: "Comparación de Sintaxis: Gecode vs GNUBison"
subtitle: "Con Fundamentos Matemáticos de CSP y AST"
author:
  - "Pipeline CSP - Motor Lógico Tipado Multidominio"
date: "Febrero 2026"
version: "2.0"
lang: es
documentclass: report
geometry: margin=1in
fontsize: 11pt
toc: true
toc-depth: 3
numbersections: true
colorlinks: true
---

\newpage

# Fundamentos Matemáticos

## Problemas de Satisfacción de Restricciones

### Definición Formal de CSP

Un **Problema de Satisfacción de Restricciones** (Constraint Satisfaction Problem, CSP) se define como una terna:

$$\mathrm{CSP} = (X, D, C)$$

donde:

- $X = \{x_1, x_2, \dots, x_n\}$ es un conjunto finito de **variables**
- $D = \{D_1, D_2, \dots, D_n\}$ es un conjunto de **dominios** finitos tales que $x_i \in D_i$
- $C = \{c_1, c_2, \dots, c_m\}$ es un conjunto de **restricciones**

Cada restricción $c_k$ está definida sobre un subconjunto de variables:

$$\mathrm{scope}(c_k) \subseteq X$$

y especifica un conjunto permitido de tuplas:

$$R_k \subseteq \prod_{x_i \in \mathrm{scope}(c_k)} D_i$$

### Asignaciones y Soluciones

Una **asignación** es una función:

$$\alpha : X \rightarrow \bigcup_i D_i \quad \text{tal que} \quad \alpha(x_i) \in D_i$$

La asignación $\alpha$ **satisface** una restricción $c_k$ si:

$$(\alpha(x_{i_1}), \dots, \alpha(x_{i_p})) \in R_k$$

donde $\mathrm{scope}(c_k)=\{x_{i_1},\dots,x_{i_p}\}$.

El CSP consiste en encontrar una asignación $\alpha$ tal que:

$$\forall c_k \in C,\; \alpha \models c_k$$

## Relación con SAT y MILP

### SAT como Caso Particular de CSP

Un problema **SAT** (Boolean Satisfiability) se define como:

$$\mathrm{SAT} = (B, \Phi)$$

donde:

- $B = \{b_1,\dots,b_n\}$ son variables booleanas
- $\Phi$ es una fórmula booleana en CNF (Forma Normal Conjuntiva)

SAT se embebe en CSP mediante:

$$D_i = \{0,1\} \quad \forall i$$

Cada cláusula $(l_1 \lor l_2 \lor \dots \lor l_k)$ se transforma en una restricción:

$$R = \{ \mathbf{v} \in \{0,1\}^k \mid l_1(\mathbf{v}) \lor \dots \lor l_k(\mathbf{v}) = 1 \}$$

Por tanto:

$$\boxed{\mathrm{SAT} \subset \mathrm{CSP}}$$

### MILP y Restricciones Lineales

Un problema **MILP** (Mixed Integer Linear Programming) se define como:

$$\begin{aligned}
\min_{x} \quad & c^T x \\
\text{sujeto a} \quad & A x \le b \\
& x_i \in \mathbb{Z} \text{ o } \mathbb{R}
\end{aligned}$$

MILP puede verse como:

- Variables con dominios potencialmente infinitos (enteros o reales)
- Restricciones lineales $Ax \le b$
- Función objetivo $c^Tx$ a minimizar

Si eliminamos la función objetivo y restringimos a dominios finitos:

$$\text{MILP (factibilidad)} \rightarrow \text{CSP lineal}$$

### Jerarquía de Expresividad

La relación entre los modelos es:

$$\boxed{\mathrm{SAT} \subset \mathrm{CSP} \subset \mathrm{CP}}$$

donde:

- **SAT**: variables booleanas únicamente
- **CSP**: dominios finitos generales
- **CP** (Constraint Programming): CSP + propagación + restricciones globales

Y en otra dimensión:

$$\mathrm{MILP} \perp \mathrm{CSP}$$

(diferentes dominios: continuo vs discreto)

Sin embargo:

$$\mathrm{MILP}_{\text{finito}} \subset \mathrm{CSP}$$

## Programación con Restricciones (CP)

### Definición de CP

La **Programación con Restricciones** generaliza CSP permitiendo:

- Dominios finitos, intervalos o conjuntos
- **Restricciones globales**: `alldiffer ent`, `cumulative`, `circuit`, etc.
- **Propagación de dominios**: reducción incremental del espacio de búsqueda
- **Búsqueda con backtracking**: exploración sistemática

### Operadores de Propagación

Formalmente, CP extiende CSP con operadores de propagación:

$$P_k : D \rightarrow D'$$

tales que:

1. $D' \subseteq D$ (reducción de dominios)
2. $\mathrm{Sol}(D') = \mathrm{Sol}(D)$ (preservación de soluciones)

### Gecode como Sistema CP

**Gecode** implementa CP sobre CSP finitos. Características:

- Solver de propósito general
- Más expresivo que SAT
- Restricciones globales eficientes
- API en C++ con bindings a otros lenguajes

Por tanto:

$$\boxed{\text{Gecode} = \text{Solver CP general}}$$

## Ubicación en la Arquitectura del Pipeline

Para ubicar los sistemas en la arquitectura:

| Sistema | Tipo | Características |
|---------|------|-----------------|
| **SAT** | Solver booleano | Variables $\in \{0,1\}$ |
| **CSP** | Solver de dominios finitos | Variables $\in D_i$ finito |
| **MILP** | Optimización lineal | Variables $\in \mathbb{Z} \cup \mathbb{R}$ |
| **Gecode** | Solver CP | CSP + propagación + globales |

\newpage

## Árbol de Sintaxis Abstracta (AST)

### Gramática Formal

Sea un **lenguaje formal** definido por una gramática:

$$G = (N, \Sigma, P, S)$$

donde:

- $N$ es un conjunto finito de **símbolos no terminales**
- $\Sigma$ es un conjunto finito de **símbolos terminales**
- $P$ es un conjunto finito de **producciones**
- $S \in N$ es el **símbolo inicial**

Cada producción tiene la forma:

$$A \rightarrow \alpha$$

con $A \in N$ y $\alpha \in (N \cup \Sigma)^*$.

### Definición Formal de AST

Un **Árbol de Sintaxis Abstracta** es un árbol dirigido etiquetado:

$$\mathrm{AST} = (V, E, \lambda)$$

donde:

- $V$ es un conjunto finito de **nodos**
- $E \subseteq V \times V$ es el conjunto de **aristas** dirigidas (padre→hijo)
- $\lambda : V \rightarrow L$ es una función de **etiquetado**

con:

$$L = \mathcal{O} \cup \mathcal{T}$$

donde:

- $\mathcal{O}$ es el conjunto de **operadores** del lenguaje
- $\mathcal{T}$ es el conjunto de **operandos** (variables, constantes)

### Propiedades del AST

**Árbol enraizado**: El AST posee un único nodo raíz:

$$\exists!\; r \in V : \nexists v \in V \text{ tal que } (v,r) \in E$$

**Alcanzabilidad**: Todo nodo es alcanzable desde la raíz:

$$\forall v \in V, \; \exists!\; \text{camino } r \rightsquigarrow v$$

### AST como Término Algebraico

Sea una **signatura algebraica**:

$$\Sigma_L = (\mathcal{O}, \mathrm{arity})$$

donde cada operador $o \in \mathcal{O}$ tiene aridad $\mathrm{arity}(o) = k$.

El conjunto de AST se define inductivamente como el conjunto de **términos**:

$$T(\Sigma_L, \mathcal{V})$$

tal que:

1. Si $v \in \mathcal{V}$ entonces $v \in T$ (variables son términos)
2. Si $o \in \mathcal{O}$, $\mathrm{arity}(o) = k$ y $t_1,\dots,t_k \in T$, entonces:

$$o(t_1,\dots,t_k) \in T$$

### Relación con el Árbol de Derivación

Sea $\mathrm{ParseTree}(G)$ el árbol de derivación de la gramática $G$.

Existe una **función de abstracción**:

$$\pi : \mathrm{ParseTree}(G) \rightarrow \mathrm{AST}(G)$$

que elimina nodos puramente sintácticos:

- Paréntesis
- Reglas auxiliares
- Información de precedencia

### Semántica Estructural

Sea $D$ un **dominio semántico**.

Una **interpretación** del lenguaje es una función:

$$[\![ \cdot ]\!] : T(\Sigma_L,\mathcal{V}) \rightarrow D$$

definida recursivamente por:

$$[\![ o(t_1,\dots,t_k) ]\!] = I(o)\big([\![ t_1 ]\!],\dots,[\![ t_k ]\!]\big)$$

donde $I(o) : D^k \rightarrow D$ es la interpretación del operador $o$.

### Ejemplo

Para la expresión:

$$(a + b) \cdot c$$

el AST es el término:

$$\mathrm{mul}(\mathrm{add}(a,b),c)$$

Gráficamente:

```
      mul
     /   \
   add    c
  /   \
 a     b
```

### Cadena de Procesamiento

Todo lenguaje formal sigue la transformación:

$$\boxed{\text{Texto} \xrightarrow{\text{Lexer}} \text{Tokens} \xrightarrow{\text{Parser}} \text{ParseTree} \xrightarrow{\pi} \text{AST} \xrightarrow{[\![\cdot]\!]} \text{Valor}}$$

### Conclusión sobre AST

Un AST es la **representación algebraica canónica** de una expresión derivada de una gramática, modelada como un árbol dirigido etiquetado que preserva únicamente la **estructura operatoria esencial** del lenguaje.

\newpage

# Introducción a la Comparación de Sintaxis

## Propósito del Documento

Este documento proporciona una comparación exhaustiva entre dos formatos de especificación de problemas lógicos:

- **Gecode**: Formato de entrada para el pipeline CSP (Constraint Satisfaction Problems)
- **GNUBison**: Formato de evaluación de expresiones con soporte de incertidumbre

Ambos sistemas operan sobre problemas de restricciones, pero con enfoques diferentes:

- **Gecode** define y **resuelve** problemas CSP
- **GNUBison** **evalúa** expresiones con valores concretos

## Diferencias Fundamentales

| Aspecto | Gecode | GNUBison |
|---------|--------|----------|
| **Propósito** | Definir y resolver CSP | Evaluar expresiones |
| **Paradigma** | Solver de restricciones | Evaluador de expresiones |
| **Incertidumbre** | No soporta | Soporta múltiples valores simultáneos |
| **Formato** | JSON con AST de restricciones | JSON con variables y expresiones |
| **Salida** | Soluciones que satisfacen restricciones | Evaluación de verdad |

## Convenciones de este Documento

- **Código en monospace**: `ejemplo`
- **Palabras clave en negrita**: **boolean**, **integer**
- **Variables en MAYÚSCULAS**: `TEMPERATURA`, `ZONA`
- **Tipos en cursiva**: *logic*, *set*, *float*

\newpage

# Sintaxis Gecode

## Estructura General

El formato Gecode usa JSON con tres secciones principales:

```json
{
  "variables": [ ... ],
  "functions": [ ... ],
  "constraints": [ ... ]
}
```

## Sección de Variables

### Estructura de Variable

```json
{
  "name": "NOMBRE_VARIABLE",
  "type": "tipo",
  "domain": [ valores_posibles ],
  "value": [ valores_iniciales ],
  "id": identificador_numérico
}
```

### Tipos de Variables

#### Tipo: boolean

**Descripción**: Variable lógica binaria (verdadero/falso)

**Representación interna**: Integer 0/1 (false=0, true=1)

**Ejemplo**:
```json
{
  "name": "PUERTA_ABIERTA",
  "type": "boolean",
  "domain": [true, false],
  "value": [false],
  "id": 0
}
```

#### Tipo: integer

**Descripción**: Variable de números enteros discretos

**Dominio**: Lista de valores enteros permitidos

**Ejemplo**:
```json
{
  "name": "INTENTOS",
  "type": "integer",
  "domain": [0, 1, 2, 3, 4, 5],
  "value": [0],
  "id": 2
}
```

#### Tipo: numeric

**Descripción**: Variable de punto flotante (escalada ×1000 internamente)

**Representación**: Integer escalado por `SCALE_NUM = 1000`

**Ejemplo**:
```json
{
  "name": "TEMPERATURA_C",
  "type": "numeric",
  "domain": [-10.0, 50.0],
  "value": [20.0],
  "id": 4
}
```

**Nota**: Internamente se representa como `20000` (20.0 × 1000).

#### Tipo: set

**Descripción**: Variable de conjunto de etiquetas

**Representación**: Índices enteros que mapean a etiquetas (strings)

**Ejemplo**:
```json
{
  "name": "ZONA",
  "type": "set",
  "domain": ["NORTE", "SUR", "ESTE", "OESTE"],
  "value": ["NORTE"],
  "id": 5
}
```

**LabelMap**: Internamente usa un mapa de índices:
```
0 → "NORTE"
1 → "SUR"
2 → "ESTE"
3 → "OESTE"
```

## Sección de Restricciones (Constraints)

### Estructura de Restricción

```json
{
  "id": número,
  "expr": "expresión_string",
  "ast": { objeto_ast },
  "vars": [lista_de_ids_de_variables]
}
```

### Ejemplo de Restricción

```json
{
  "id": 0,
  "expr": "PUERTA_ABIERTA = false",
  "ast": {
    "op": "EQ",
    "left": { "type": "var", "name": "PUERTA_ABIERTA" },
    "right": { "type": "const", "value": false }
  },
  "vars": [0]
}
```

## Sección de Funciones

### Funciones Definidas por Usuario

```json
{
  "name": "calcular_riesgo",
  "params": ["intentos", "nivel"],
  "body": {
    "ast": { expresión_ast },
    "expr": "intentos + nivel * 2"
  }
}
```

\newpage

# Sintaxis GNUBison

## Estructura General

El formato GNUBison usa JSON simplificado:

```json
{
  "precision": número_decimales,
  "variables": [ ... ],
  "expresiones": [ ... ]
}
```

## Sección de Variables

### Estructura de Variable

```json
{
  "nombre": "NOMBRE_VARIABLE",
  "tipo": "tipo",
  "domain": [ valores ],
  "value": valor_o_valores
}
```

### Tipos de Variables

#### Tipo: logic

**Equivalente Gecode**: `boolean`

**Valores**: `true` / `false` o `0` / `1`

**Ejemplo**:
```json
{
  "nombre": "PUERTA_ABIERTA",
  "tipo": "logic",
  "value": false
}
```

#### Tipo: integer

**Equivalente Gecode**: `integer`

**Valores**: Números enteros

**Ejemplo**:
```json
{
  "nombre": "INTENTOS",
  "tipo": "integer",
  "value": 3
}
```

#### Tipo: float

**Equivalente Gecode**: `numeric`

**Valores**: Números de punto flotante

**Ejemplo**:
```json
{
  "nombre": "TEMPERATURA_C",
  "tipo": "float",
  "value": 20.5
}
```

#### Tipo: set

**Equivalente Gecode**: `set`

**Valores**: Array de strings (etiquetas)

**Ejemplo**:
```json
{
  "nombre": "ZONA",
  "tipo": "set",
  "value": ["NORTE", "SUR"]
}
```

**Incertidumbre**: GNUBison soporta múltiples valores simultáneos.

## Sección de Expresiones

### Expresiones como Strings

```json
{
  "expresiones": [
    "PUERTA_ABIERTA = false",
    "INTENTOS + NIVEL_ALERTA <= 4",
    "TEMPERATURA_C >= 15.0 AND TEMPERATURA_C <= 25.0"
  ]
}
```

### Operadores Soportados

**Aritméticos**: `+`, `-`, `*`, `/`

**Comparación**: `=`, `<>`, `<`, `>`, `<=`, `>=`

**Lógicos**: `AND`, `OR`, `NOT`, `IMPLICA`

**Conjuntos**: `UNION`, `INTERSECT`, `DIFFERENCE`, `SUBSET`, `IN`, `CARDINALITY`

## Formato de Salida

### Resultado de Evaluación

```json
{
  "resumen": {
    "valido": true,
    "total_expresiones": 11,
    "expresiones_validas": 11,
    "expresiones_invalidas": 0,
    "errores": 0
  },
  "detalles": [
    {
      "expresion": "PUERTA_ABIERTA = false",
      "resultado": true,
      "mensaje": "Expresión válida"
    }
  ]
}
```

\newpage

# Comparación Detallada

## Tabla Comparativa: Campos de Variables

| Campo | Gecode | GNUBison | Transformación |
|-------|--------|----------|----------------|
| Nombre | `name` | `nombre` | Renombrar campo |
| Tipo | `type` | `tipo` | Renombrar campo |
| Dominio | `domain` | `domain` | Sin cambios |
| Valor | `value` | `value` | Sin cambios |
| ID | `id` | - | Eliminar (no usado) |

## Tabla Comparativa: Tipos de Datos

| Gecode | GNUBison | Conversión |
|--------|----------|------------|
| `boolean` | `logic` | Cambiar nombre del tipo |
| `integer` | `integer` | Sin cambios |
| `numeric` | `float` | Dividir valor por 1000 |
| `set` | `set` | Convertir índices a labels |

### Transformación de Tipos

#### Boolean → Logic

```
Gecode:   type="boolean", value=[0]
GNUBison: tipo="logic", value=false
```

#### Numeric → Float

```
Gecode:   type="numeric", value=[20000]  # ×1000
GNUBison: tipo="float", value=20.0       # ÷1000
```

#### Set → Set (con labels)

```
Gecode:   type="set", value=[0]          # índice
          LabelMap: 0 → "NORTE"
GNUBison: tipo="set", value=["NORTE"]    # label
```

## Tabla Comparativa: Estructura

| Aspecto | Gecode | GNUBison |
|---------|--------|----------|
| **Formato raíz** | Objeto con 3 secciones | Objeto con 2-3 secciones |
| **Variables** | Array `variables[]` | Array `variables[]` |
| **Restricciones** | Array `constraints[]` con AST | Array `expresiones[]` (strings) |
| **Funciones** | Array `functions[]` | No soporta |
| **AST** | Sí, explícito | No, solo strings |

\newpage

# Gramática Formal

## Gramática Gecode (EBNF)

```ebnf
GeCodeJSON ::= "{"
                 "\"variables\":" "[" VariableList "]" ","
                 "\"functions\":" "[" FunctionList "]" ","
                 "\"constraints\":" "[" ConstraintList "]"
               "}"

VariableList ::= Variable ("," Variable)*

Variable ::= "{"
               "\"name\":" STRING ","
               "\"type\":" VarType ","
               "\"domain\":" Domain ","
               "\"value\":" Value ","
               "\"id\":" NUMBER
             "}"

VarType ::= "\"boolean\"" | "\"integer\"" | "\"numeric\"" | "\"set\""

Domain ::= "[" ValueList "]"

Constraint ::= "{"
                 "\"id\":" NUMBER ","
                 "\"expr\":" STRING ","
                 "\"ast\":" AST ","
                 "\"vars\":" "[" IDList "]"
               "}"

AST ::= "{"
          "\"op\":" OPERATOR ","
          "\"left\":" AST ","
          "\"right\":" AST
        "}"
      | "{"
          "\"type\":\"var\"" ","
          "\"name\":" STRING
        "}"
      | "{"
          "\"type\":\"const\"" ","
          "\"value\":" VALUE
        "}"
```

## Gramática GNUBison (EBNF)

```ebnf
BisonJSON ::= "{"
                "\"precision\":" NUMBER ","
                "\"variables\":" "[" VariableList "]" ","
                "\"expresiones\":" "[" ExprList "]"
              "}"

Variable ::= "{"
               "\"nombre\":" STRING ","
               "\"tipo\":" VarType ","
               "\"domain\":" Domain ","
               "\"value\":" Value
             "}"

VarType ::= "\"logic\"" | "\"integer\"" | "\"float\"" | "\"set\""

ExprList ::= STRING ("," STRING)*

Expression ::= Term (CompOp Term)*

Term ::= Factor (("+"|"-") Factor)*

Factor ::= Primary (("*"|"/") Primary)*

Primary ::= NUMBER
          | BOOLEAN
          | VARIABLE
          | "(" Expression ")"
          | UnaryOp Primary

CompOp ::= "=" | "<>" | "<" | ">" | "<=" | ">="

UnaryOp ::= "NOT" | "-"
```

\newpage

# Transformaciones

## Algoritmo de Transformación Gecode → GNUBison

### Paso 1: Transformar Variables

```python
def transformar_variable(var_gecode):
    var_bison = {}
    var_bison["nombre"] = var_gecode["name"]
    var_bison["tipo"] = transformar_tipo(var_gecode["type"])
    var_bison["domain"] = var_gecode["domain"]
    var_bison["value"] = transformar_valor(
        var_gecode["value"],
        var_gecode["type"]
    )
    return var_bison
```

### Paso 2: Transformar Tipos

```python
def transformar_tipo(tipo_gecode):
    mapa = {
        "boolean": "logic",
        "integer": "integer",
        "numeric": "float",
        "set": "set"
    }
    return mapa[tipo_gecode]
```

### Paso 3: Transformar Valores

```python
def transformar_valor(valor, tipo):
    if tipo == "boolean":
        return valor[0] == 1  # 0/1 → false/true
    elif tipo == "numeric":
        return valor[0] / 1000.0  # Escala ÷1000
    elif tipo == "set":
        return [label_map[idx] for idx in valor]
    else:  # integer
        return valor[0]
```

### Paso 4: Extraer Expresiones

```python
def extraer_expresiones(constraints):
    return [c["expr"] for c in constraints]
```

## Ejemplo Completo de Transformación

### Entrada Gecode:

```json
{
  "variables": [
    {
      "name": "TEMP",
      "type": "numeric",
      "domain": [15.0, 30.0],
      "value": [20000],
      "id": 0
    }
  ],
  "constraints": [
    {
      "id": 0,
      "expr": "TEMP >= 15.0",
      "vars": [0]
    }
  ]
}
```

### Salida GNUBison:

```json
{
  "precision": 2,
  "variables": [
    {
      "nombre": "TEMP",
      "tipo": "float",
      "domain": [15.0, 30.0],
      "value": 20.0
    }
  ],
  "expresiones": [
    "TEMP >= 15.0"
  ]
}
```

\newpage

# Referencia Rápida

## Tabla de Transformación Rápida

| Concepto | Gecode | GNUBison |
|----------|--------|----------|
| **Campo nombre** | `name` | `nombre` |
| **Campo tipo** | `type` | `tipo` |
| **Boolean** | `boolean` (0/1) | `logic` (true/false) |
| **Numérico** | `numeric` (×1000) | `float` (÷1000) |
| **Set** | Índices + LabelMap | Array de strings |
| **Restricciones** | `constraints[]` + AST | `expresiones[]` (strings) |
| **Funciones** | `functions[]` | No soporta |

## Operadores Comunes

| Operador | Gecode | GNUBison | Tipo |
|----------|--------|----------|------|
| Igualdad | `=` | `=` | Comparación |
| Desigualdad | `<>` | `<>` | Comparación |
| Suma | `+` | `+` | Aritmético |
| Resta | `-` | `-` | Aritmético |
| AND lógico | `AND` | `AND` | Lógico |
| OR lógico | `OR` | `OR` | Lógico |
| NOT lógico | `NOT` | `NOT` | Lógico |
| Pertenencia | `IN` | `IN` | Conjuntos |

\newpage

# Conclusiones

## Resumen de Diferencias

1. **Gecode** es un sistema de **modelado y resolución** de CSP
2. **GNUBison** es un **evaluador** de expresiones con valores concretos
3. Gecode usa **AST explícito**, GNUBison usa **expresiones como strings**
4. GNUBison soporta **incertidumbre** (múltiples valores simultáneos)
5. La transformación entre formatos es **directa** pero requiere:
   - Renombrado de campos
   - Conversión de tipos
   - Escalado de valores numéricos
   - Mapeo de índices a etiquetas (sets)

## Uso en el Pipeline

El pipeline CSP utiliza:

1. **Gecode** para **resolver** el CSP y encontrar soluciones
2. **GNUBison** para **verificar** que las soluciones satisfacen las expresiones originales
3. **VerifyWithBison** como componente que:
   - Lee soluciones de Gecode
   - Transforma al formato GNUBison
   - Invoca el evaluador
   - Reporta verificación

Esta arquitectura proporciona **validación cruzada** de resultados.

## Referencias

- Gecode: <https://www.gecode.org/>
- GNUBison: `/home/rodo/GNUBison/`
- Pipeline CSP: `/home/rodo/gecode/`
- Documentación VerifyWithBison: `docs/VerifyWithBison.txt`

\newpage

# Apéndices

## Apéndice A: Códigos de Error

| Código | Descripción | Sistema |
|--------|-------------|---------|
| 1 | Error de sintaxis JSON | Ambos |
| 2 | Tipo de variable inválido | Ambos |
| 3 | Dominio vacío | Gecode |
| 4 | Variable no declarada | GNUBison |
| 5 | Expresión inválida | GNUBison |

## Apéndice B: Funciones Matemáticas

### Gecode (vía MiniMath)

- `sin(x)`, `cos(x)`, `tan(x)`
- `sqrt(x)`, `pow(x, y)`
- `log(x)`, `exp(x)`
- `abs(x)`, `min(x,y)`, `max(x,y)`

### GNUBison

- Operadores aritméticos básicos
- Operadores lógicos
- Operadores de conjuntos
- No soporta funciones trigonométricas (aún)

## Apéndice C: Glosario

- **AST**: Abstract Syntax Tree (Árbol de Sintaxis Abstracta)
- **CP**: Constraint Programming (Programación con Restricciones)
- **CSP**: Constraint Satisfaction Problem (Problema de Satisfacción de Restricciones)
- **EBNF**: Extended Backus-Naur Form (Forma de Backus-Naur Extendida)
- **MILP**: Mixed Integer Linear Programming (Programación Lineal Entera Mixta)
- **SAT**: Boolean Satisfiability Problem (Problema de Satisfacibilidad Booleana)

---

**Fin del Documento**
