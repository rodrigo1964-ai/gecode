# Fundamentos Matemáticos

## Problemas de Satisfacción de Restricciones y su relación con SAT y MILP

### Definición formal de un Problema de Satisfacción de Restricciones (CSP)

Un **Problema de Satisfacción de Restricciones** (Constraint Satisfaction Problem, CSP) se define como una terna:

$$\mathrm{CSP} = (X, D, C)$$

donde:

- $X = \{x_1, x_2, \dots, x_n\}$ es un conjunto finito de variables.
- $D = \{D_1, D_2, \dots, D_n\}$ es un conjunto de dominios finitos tales que $x_i \in D_i$.
- $C = \{c_1, c_2, \dots, c_m\}$ es un conjunto de restricciones.

Cada restricción $c_k$ está definida sobre un subconjunto de variables

$$\mathrm{scope}(c_k) \subseteq X$$

y especifica un conjunto permitido de tuplas:

$$R_k \subseteq \prod_{x_i \in \mathrm{scope}(c_k)} D_i$$

Una **asignación** es una función:

$$\alpha : X \rightarrow \bigcup_i D_i \quad \text{tal que} \quad \alpha(x_i) \in D_i$$

La asignación $\alpha$ satisface una restricción $c_k$ si:

$$(\alpha(x_{i_1}), \dots, \alpha(x_{i_p})) \in R_k \quad \text{con } \mathrm{scope}(c_k)=\{x_{i_1},\dots,x_{i_p}\}$$

El CSP consiste en encontrar:

$$\alpha \text{ tal que } \forall c_k \in C,\; \alpha \models c_k$$

### SAT como caso particular de CSP

Un problema SAT puede definirse como:

$$\mathrm{SAT} = (B, \Phi)$$

donde:

- $B = \{b_1,\dots,b_n\}$ variables booleanas
- $\Phi$ fórmula booleana en CNF

SAT se embebe en CSP mediante:

$$D_i = \{0,1\}$$

y cada cláusula:

$$(l_1 \lor l_2 \lor \dots \lor l_k)$$

se transforma en una restricción:

$$R = \{ \mathbf{v} \in \{0,1\}^k \mid l_1(\mathbf{v}) \lor \dots \lor l_k(\mathbf{v}) = 1 \}$$

Por tanto:

$$\mathrm{SAT} \subset \mathrm{CSP}$$

### MILP como problema de optimización con restricciones lineales

Un problema MILP (Mixed Integer Linear Programming) se define como:

$$\begin{aligned}
\min_{x} \quad & c^T x \\
\text{sujeto a} \quad & A x \le b \\
& x_i \in \mathbb{Z} \ \text{o} \ \mathbb{R}
\end{aligned}$$

MILP puede verse como:

- variables con dominios infinitos (enteros o reales)
- restricciones lineales
- función objetivo

Si se elimina la función objetivo y se restringen dominios finitos:

$$\text{MILP factibilidad} \rightarrow \text{CSP lineal}$$

### Programación con Restricciones (CP) y Gecode

La Programación con Restricciones (Constraint Programming, CP) generaliza CSP permitiendo:

- dominios finitos, intervalos o conjuntos
- restricciones globales (alldifferent, cumulative, etc.)
- propagación de dominios
- búsqueda con backtracking

Formalmente, CP extiende CSP con operadores de propagación:

$$P_k : D \rightarrow D' \quad \text{tal que } D' \subseteq D$$

y mantiene:

$$\mathrm{Sol}(D') = \mathrm{Sol}(D)$$

Gecode implementa CP sobre CSP finitos, por lo que:

$$\mathrm{SAT} \subset \mathrm{CSP} \subset \mathrm{CP}$$

y Gecode es un solver CP general.

### Relación de expresividad

Podemos ubicar los modelos:

$$\mathrm{SAT} \subset \mathrm{CSP} \subset \mathrm{CP}$$

y en otra dimensión:

$$\mathrm{MILP} \perp \mathrm{CSP}$$

(diferentes dominios: continuo vs discreto)

Sin embargo:

$$\mathrm{MILP}_{finito} \subset \mathrm{CSP}$$

### Ubicación en la arquitectura del pipeline

Para ubicarlo en la arquitectura:

- **SAT** → variables booleanas
- **CSP** → dominios finitos generales
- **MILP** → optimización lineal

**Gecode = CSP/CP general** (más expresivo que SAT).

### Conclusión estructural

- SAT es CSP con dominios booleanos
- CSP es modelo discreto general
- CP es CSP + propagación + globales
- MILP es optimización lineal continua/discreta
- Gecode implementa CP sobre CSP finitos

---

## Árbol de Sintaxis Abstracta (AST)

### Gramática de un lenguaje formal

Sea un lenguaje formal definido por una gramática:

$$G = (N, \Sigma, P, S)$$

donde:

- $N$ es un conjunto finito de símbolos no terminales
- $\Sigma$ es un conjunto finito de símbolos terminales
- $P$ es un conjunto finito de producciones
- $S \in N$ es el símbolo inicial

Cada producción tiene la forma:

$$A \rightarrow \alpha \quad \text{con } A \in N,\; \alpha \in (N \cup \Sigma)^*$$

### Definición formal de AST

Un **Árbol de Sintaxis Abstracta** (AST) es un árbol dirigido etiquetado:

$$\mathrm{AST} = (V, E, \lambda)$$

donde:

- $V$ es un conjunto finito de nodos
- $E \subseteq V \times V$ es el conjunto de aristas dirigidas (relación padre–hijo)
- $\lambda : V \rightarrow L$ es una función de etiquetado

con:

$$L = \mathcal{O} \cup \mathcal{T}$$

donde:

- $\mathcal{O}$ es el conjunto de operadores del lenguaje
- $\mathcal{T}$ es el conjunto de operandos (variables, constantes)

### Propiedad de árbol enraizado

El AST posee un único nodo raíz:

$$\exists!\; r \in V \text{ tal que } \nexists v \in V : (v,r) \in E$$

y todo nodo es alcanzable desde la raíz:

$$\forall v \in V,\; \exists!\; \text{camino } r \rightsquigarrow v$$

### AST como término algebraico

Sea una signatura algebraica del lenguaje:

$$\Sigma_L = (\mathcal{O}, \mathrm{arity})$$

donde cada operador $o \in \mathcal{O}$ tiene aridad:

$$\mathrm{arity}(o) = k$$

El conjunto de AST se define inductivamente como el conjunto de términos:

$$T(\Sigma_L, \mathcal{V})$$

tal que:

- si $v \in \mathcal{V}$ entonces $v \in T$
- si $o \in \mathcal{O}$ y $t_1,\dots,t_k \in T$ entonces $o(t_1,\dots,t_k) \in T$

### Relación con el árbol sintáctico concreto

Sea $\mathrm{ParseTree}(G)$ el árbol de derivación de la gramática.

Existe una función de abstracción:

$$\pi : \mathrm{ParseTree}(G) \rightarrow \mathrm{AST}(G)$$

que elimina nodos puramente sintácticos (paréntesis, reglas auxiliares, precedencia).

### Semántica estructural del AST

Sea $D$ un dominio semántico.

Una interpretación del lenguaje es una función:

$$[\![ \cdot ]\!] : T(\Sigma_L,\mathcal{V}) \rightarrow D$$

definida recursivamente por:

$$[\![ o(t_1,\dots,t_k) ]\!] = I(o)\big([\![ t_1 ]\!],\dots,[\![ t_k ]\!]\big)$$

donde:

$$I(o) : D^k \rightarrow D$$

### Ejemplo

Para la expresión:

$$(a + b)\cdot c$$

el AST es el término:

$$\mathrm{mul}(\mathrm{add}(a,b),c)$$

### Cadena de representación

Todo lenguaje formal sigue la transformación:

$$\text{Texto} \rightarrow \text{ParseTree} \rightarrow \text{AST} \rightarrow \text{Semántica}$$

### Conclusión sobre AST

Un AST es la representación algebraica canónica de una expresión derivada de una gramática, modelada como un árbol dirigido etiquetado que preserva únicamente la estructura operatoria esencial del lenguaje.
