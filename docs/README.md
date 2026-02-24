# Documentación GeCode CSP Pipeline

Esta carpeta contiene la documentación completa del proyecto en formato Markdown y PDF.

## 📚 Documentos Disponibles

### Documentos Principales (Formato Markdown)

- **01_introduccion.md** - Introducción, características y compilación
- **02_arquitectura.md** - Arquitectura del sistema y flujo de datos
- **03_componentes_pipeline.md** - Detalles de cada componente
- **04_integracion_gecode.md** - Puente C++/Pascal y API de Gecode
- **estructura_proyecto.md** - Organización de directorios y dependencias

### Reportes de Pruebas

- **reporte_prueba_pipeline_basico.md** - Validación del pipeline con ejemplos básicos
- **reporte_prueba_gecode_completo.md** - Pruebas de integración con Gecode
- **reporte_prueba_persistencia_sqlite.md** - Pruebas de persistencia en SQLite

### Documentación Técnica de Componentes (.txt)

- `SyntaxChecker.txt` - Validador de sintaxis JSON
- `JsonToGraph.txt` - Constructor de grafos AST
- `FunctionChecker.txt` - Verificador de funciones
- `FwdConsistency.txt` - Propagación forward (AC-3)
- `BwdConsistency.txt` - Proyección inversa
- `CSPEval.txt` - Evaluador de expresiones
- `TestGecodeBridge.txt` - Integración Gecode
- `monolitico.txt` - Guía de compilación monolítica

### Formato PDF

Los PDFs se generan automáticamente desde los archivos Markdown.

## 🔨 Generar PDFs

### Requisitos

Instalar `pandoc` y LaTeX:

```bash
# Ubuntu/Debian
sudo apt install pandoc texlive-latex-base texlive-fonts-recommended texlive-latex-extra

# Fedora/RHEL
sudo dnf install pandoc texlive-scheme-basic texlive-collection-fontsrecommended

# macOS (Homebrew)
brew install pandoc
brew install --cask basictex
```

### Generar Todos los PDFs

Desde el directorio raíz del proyecto:

```bash
./generar_pdfs.sh
```

Esto generará:

- `docs/pdf/01_introduccion.pdf`
- `docs/pdf/02_arquitectura.pdf`
- `docs/pdf/03_componentes_pipeline.pdf`
- `docs/pdf/04_integracion_gecode.pdf`
- `docs/pdf/GeCode_CSP_Pipeline_Manual_Completo.pdf` (todos combinados)

### Generar PDF Individual

```bash
# Solo introducción
pandoc docs/01_introduccion.md -o introduccion.pdf --pdf-engine=pdflatex --toc

# Solo arquitectura
pandoc docs/02_arquitectura.md -o arquitectura.pdf --pdf-engine=pdflatex --toc
```

## 📖 Contenido de los Documentos

### 01. Introducción
- ¿Qué es GeCode CSP Pipeline?
- Características principales
- Tipos de datos y operadores soportados
- Compilación e instalación
- Inicio rápido

### 02. Arquitectura
- Visión general del sistema
- Flujo de datos del pipeline
- Componentes y sus interacciones
- Persistencia en SQLite
- Diagrama de arquitectura

### 03. Componentes del Pipeline
- **SyntaxChecker**: Validación de sintaxis JSON
- **JsonToGraph**: Construcción de AST y grafos
- **FunctionChecker**: Verificación de funciones
- **FwdConsistency**: Propagación AC-3
- **BwdConsistency**: Análisis de intervalos inverso
- **CSPEval**: Evaluación de expresiones
- **ForwardChain**: Encadenamiento hacia adelante
- Herramientas de persistencia (JsonSink/JsonSource)

### 04. Integración con Gecode
- Arquitectura del puente C++/Pascal
- API exportada desde C++
- Estructuras de datos compartidas
- Compilación monolítica (estática/dinámica)
- Programas de prueba
- Casos de uso con Gecode

## 🎯 Estructura de Cada Documento

Cada documento principal incluye:

1. **Metadatos YAML** - Para generación de PDFs con pandoc
2. **Introducción** - Contexto y propósito
3. **Secciones detalladas** - Contenido técnico
4. **Ejemplos de código** - Casos de uso prácticos
5. **Diagramas ASCII** - Visualización de conceptos
6. **Referencias** - Enlaces a otros documentos

## 📁 Estructura del Directorio

```
docs/
├── README.md                                # Este archivo
├── 01_introduccion.md                       # Introducción y compilación
├── 02_arquitectura.md                       # Arquitectura del sistema
├── 03_componentes_pipeline.md               # Componentes detallados
├── 04_integracion_gecode.md                 # Integración con Gecode
├── estructura_proyecto.md                   # Organización del proyecto
├── reporte_prueba_pipeline_basico.md        # Reporte de pruebas
├── reporte_prueba_gecode_completo.md        # Reporte Gecode
├── reporte_prueba_persistencia_sqlite.md    # Reporte SQLite
├── SyntaxChecker.txt                        # Doc técnica
├── JsonToGraph.txt                          # Doc técnica
├── FunctionChecker.txt                      # Doc técnica
├── FwdConsistency.txt                       # Doc técnica
├── BwdConsistency.txt                       # Doc técnica
├── CSPEval.txt                              # Doc técnica
├── TestGecodeBridge.txt                     # Doc técnica
├── monolitico.txt                           # Doc técnica
└── pdf/                                     # PDFs generados
    ├── 01_introduccion.pdf
    ├── 02_arquitectura.pdf
    ├── 03_componentes_pipeline.pdf
    ├── 04_integracion_gecode.pdf
    └── GeCode_CSP_Pipeline_Manual_Completo.pdf
```

## 🚀 Uso Rápido

```bash
# Generar todos los PDFs
./generar_pdfs.sh

# Ver PDFs generados
ls -lh docs/pdf/

# Abrir PDF completo (Linux)
xdg-open docs/pdf/GeCode_CSP_Pipeline_Manual_Completo.pdf

# Abrir PDF completo (macOS)
open docs/pdf/GeCode_CSP_Pipeline_Manual_Completo.pdf
```

## 📝 Actualizar Documentación

1. Editar archivos `.md` en `docs/`
2. Ejecutar `./generar_pdfs.sh`
3. Los PDFs se regeneran automáticamente

## 🎨 Personalización de PDFs

Para modificar el estilo de los PDFs, editar las opciones en `generar_pdfs.sh`:

- `--toc`: Tabla de contenidos automática
- `--toc-depth=N`: Profundidad del índice (1-6)
- `-V papersize=VALUE`: Tamaño de página (letter, a4)
- `-V fontsize=VALUE`: Tamaño de fuente (10pt, 11pt, 12pt)
- `-V geometry:margin=VALUE`: Márgenes (2cm, 2.5cm, etc.)
- `--pdf-engine=ENGINE`: Motor PDF (pdflatex, xelatex, lualatex)

## 🔗 Enlaces Relacionados

- **README principal**: `../README.md`
- **Ejemplos**: `../ejemplos/README.md`
- **Código fuente**: `../src/`
- **Scripts**: `../scripts/`

## 📧 Soporte

Para más información sobre el proyecto, consultar:

1. README principal en el directorio raíz
2. Documentación de componentes individuales (.txt)
3. Ejemplos en `../ejemplos/`

---

**Nota**: Esta documentación se mantiene sincronizada con el código fuente. Al actualizar el código, actualizar también la documentación correspondiente.
