#!/bin/bash
# Script para generar PDFs de la documentación - GeCode CSP Pipeline

echo "================================================="
echo "  Generando PDFs - GeCode CSP Pipeline"
echo "================================================="
echo ""

# Crear directorios
mkdir -p docs/pdf docs/.temp

# Verificar pandoc
if ! command -v pandoc &> /dev/null; then
    echo "ERROR: pandoc no está instalado"
    echo "Instalar: sudo apt install pandoc texlive-latex-base texlive-fonts-recommended texlive-latex-extra"
    exit 1
fi

echo "pandoc: $(pandoc --version | head -1)"
echo ""

# Función para limpiar caracteres Unicode problemáticos
limpiar_emojis() {
    # Conversión agresiva a ASCII para máxima compatibilidad con LaTeX
    iconv -f UTF-8 -t ASCII//TRANSLIT "$1" 2>/dev/null > "$2"
}

# ==== DOCUMENTOS PRINCIPALES ====

echo "=== Documentos Principales ==="
echo ""

# 01_introduccion.pdf
echo "Generando: 01_introduccion.pdf..."
limpiar_emojis "docs/01_introduccion.md" "docs/.temp/01_clean.md"
pandoc docs/.temp/01_clean.md -o docs/pdf/01_introduccion.pdf \
    --pdf-engine=pdflatex -V papersize=letter -V fontsize=11pt \
    -V geometry:margin=2.5cm --toc --toc-depth=3 --highlight-style=tango 2>/dev/null
[ -f docs/pdf/01_introduccion.pdf ] && echo "   [OK] 01_introduccion.pdf" || echo "   [ERROR]"

# 02_arquitectura.pdf
echo "Generando: 02_arquitectura.pdf..."
limpiar_emojis "docs/02_arquitectura.md" "docs/.temp/02_clean.md"
pandoc docs/.temp/02_clean.md -o docs/pdf/02_arquitectura.pdf \
    --pdf-engine=pdflatex -V papersize=letter -V fontsize=11pt \
    -V geometry:margin=2.5cm --toc --toc-depth=3 --highlight-style=tango 2>/dev/null
[ -f docs/pdf/02_arquitectura.pdf ] && echo "   [OK] 02_arquitectura.pdf" || echo "   [ERROR]"

# 03_componentes_pipeline.pdf
echo "Generando: 03_componentes_pipeline.pdf..."
limpiar_emojis "docs/03_componentes_pipeline.md" "docs/.temp/03_clean.md"
pandoc docs/.temp/03_clean.md -o docs/pdf/03_componentes_pipeline.pdf \
    --pdf-engine=pdflatex -V papersize=letter -V fontsize=11pt \
    -V geometry:margin=2.5cm --toc --toc-depth=3 --highlight-style=tango 2>/dev/null
[ -f docs/pdf/03_componentes_pipeline.pdf ] && echo "   [OK] 03_componentes_pipeline.pdf" || echo "   [ERROR]"

# 04_integracion_gecode.pdf
echo "Generando: 04_integracion_gecode.pdf..."
limpiar_emojis "docs/04_integracion_gecode.md" "docs/.temp/04_clean.md"
pandoc docs/.temp/04_clean.md -o docs/pdf/04_integracion_gecode.pdf \
    --pdf-engine=pdflatex -V papersize=letter -V fontsize=11pt \
    -V geometry:margin=2.5cm --toc --toc-depth=3 --highlight-style=tango 2>/dev/null
[ -f docs/pdf/04_integracion_gecode.pdf ] && echo "   [OK] 04_integracion_gecode.pdf" || echo "   [ERROR]"

echo ""

# ==== REPORTES DE PRUEBAS ====

echo "=== Reportes de Pruebas ==="
echo ""

# reporte_prueba_pipeline_basico.pdf
echo "Generando: reporte_prueba_pipeline_basico.pdf..."
limpiar_emojis "docs/reporte_prueba_pipeline_basico.md" "docs/.temp/rp1_clean.md"
pandoc docs/.temp/rp1_clean.md -o docs/pdf/reporte_prueba_pipeline_basico.pdf \
    --pdf-engine=pdflatex -V papersize=letter -V fontsize=11pt \
    -V geometry:margin=2cm --toc --toc-depth=2 --highlight-style=tango 2>/dev/null
[ -f docs/pdf/reporte_prueba_pipeline_basico.pdf ] && echo "   [OK]" || echo "   [ERROR]"

# reporte_prueba_gecode_completo.pdf
echo "Generando: reporte_prueba_gecode_completo.pdf..."
limpiar_emojis "docs/reporte_prueba_gecode_completo.md" "docs/.temp/rp2_clean.md"
pandoc docs/.temp/rp2_clean.md -o docs/pdf/reporte_prueba_gecode_completo.pdf \
    --pdf-engine=pdflatex -V papersize=letter -V fontsize=11pt \
    -V geometry:margin=2cm --toc --toc-depth=2 --highlight-style=tango 2>/dev/null
[ -f docs/pdf/reporte_prueba_gecode_completo.pdf ] && echo "   [OK]" || echo "   [ERROR]"

# reporte_prueba_persistencia_sqlite.pdf
echo "Generando: reporte_prueba_persistencia_sqlite.pdf..."
limpiar_emojis "docs/reporte_prueba_persistencia_sqlite.md" "docs/.temp/rp3_clean.md"
pandoc docs/.temp/rp3_clean.md -o docs/pdf/reporte_prueba_persistencia_sqlite.pdf \
    --pdf-engine=pdflatex -V papersize=letter -V fontsize=11pt \
    -V geometry:margin=2cm --toc --toc-depth=2 --highlight-style=tango 2>/dev/null
[ -f docs/pdf/reporte_prueba_persistencia_sqlite.pdf ] && echo "   [OK]" || echo "   [ERROR]"

echo ""

# ==== MANUAL COMPLETO ====

echo "=== Manual Completo ==="
echo ""
echo "Generando: GeCode_CSP_Pipeline_Manual_Completo.pdf..."

pandoc \
    docs/.temp/01_clean.md \
    docs/.temp/02_clean.md \
    docs/.temp/03_clean.md \
    docs/.temp/04_clean.md \
    -o docs/pdf/GeCode_CSP_Pipeline_Manual_Completo.pdf \
    --pdf-engine=pdflatex \
    -V papersize=letter \
    -V fontsize=11pt \
    -V geometry:margin=2.5cm \
    --toc \
    --toc-depth=3 \
    --highlight-style=tango \
    --metadata title="GeCode CSP Pipeline - Manual Completo" \
    --metadata subtitle="Sistema de Procesamiento de Problemas de Constraint Programming" \
    --metadata author="Proyecto GeCode CSP Pipeline" \
    --metadata date="2026" \
    2>/dev/null

[ -f docs/pdf/GeCode_CSP_Pipeline_Manual_Completo.pdf ] && echo "   [OK] Manual Completo" || echo "   [ERROR]"

# Limpiar temporales
rm -rf docs/.temp

echo ""
echo "================================================="
echo "  Resumen de PDFs Generados"
echo "================================================="
echo ""

if [ -n "$(ls -A docs/pdf/*.pdf 2>/dev/null)" ]; then
    echo "Documentación Principal:"
    [ -f docs/pdf/01_introduccion.pdf ] && printf "  %-45s %s\n" "01_introduccion.pdf" "$(ls -lh docs/pdf/01_introduccion.pdf | awk '{print $5}')"
    [ -f docs/pdf/02_arquitectura.pdf ] && printf "  %-45s %s\n" "02_arquitectura.pdf" "$(ls -lh docs/pdf/02_arquitectura.pdf | awk '{print $5}')"
    [ -f docs/pdf/03_componentes_pipeline.pdf ] && printf "  %-45s %s\n" "03_componentes_pipeline.pdf" "$(ls -lh docs/pdf/03_componentes_pipeline.pdf | awk '{print $5}')"
    [ -f docs/pdf/04_integracion_gecode.pdf ] && printf "  %-45s %s\n" "04_integracion_gecode.pdf" "$(ls -lh docs/pdf/04_integracion_gecode.pdf | awk '{print $5}')"

    echo ""
    echo "Reportes de Pruebas:"
    [ -f docs/pdf/reporte_prueba_pipeline_basico.pdf ] && printf "  %-45s %s\n" "reporte_prueba_pipeline_basico.pdf" "$(ls -lh docs/pdf/reporte_prueba_pipeline_basico.pdf | awk '{print $5}')"
    [ -f docs/pdf/reporte_prueba_gecode_completo.pdf ] && printf "  %-45s %s\n" "reporte_prueba_gecode_completo.pdf" "$(ls -lh docs/pdf/reporte_prueba_gecode_completo.pdf | awk '{print $5}')"
    [ -f docs/pdf/reporte_prueba_persistencia_sqlite.pdf ] && printf "  %-45s %s\n" "reporte_prueba_persistencia_sqlite.pdf" "$(ls -lh docs/pdf/reporte_prueba_persistencia_sqlite.pdf | awk '{print $5}')"

    echo ""
    echo "Manual Completo:"
    [ -f docs/pdf/GeCode_CSP_Pipeline_Manual_Completo.pdf ] && printf "  %-45s %s\n" "GeCode_CSP_Pipeline_Manual_Completo.pdf" "$(ls -lh docs/pdf/GeCode_CSP_Pipeline_Manual_Completo.pdf | awk '{print $5}')"

    echo ""
    echo "Total: $(ls -1 docs/pdf/*.pdf 2>/dev/null | wc -l) PDFs generados"
    echo "Ubicación: docs/pdf/"
else
    echo "No se generaron PDFs"
fi

echo ""
echo "================================================="
echo "Proceso Completado"
echo "================================================="
echo ""
echo "Visualizar: xdg-open docs/pdf/GeCode_CSP_Pipeline_Manual_Completo.pdf"
echo ""
