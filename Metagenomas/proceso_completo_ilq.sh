#!/bin/bash

# Script completo: limpia eggnog y genera GBKs por chunks
# Localidad: ilq (prueba)
# Ejecutar: chmod +x proceso_completo_ilq.sh && ./proceso_completo_ilq.sh

echo "================================================"
echo "PROCESO COMPLETO: LIMPIEZA + GENERACIÓN GBKs"
echo "Localidad: ilq"
echo "Fecha: $(date)"
echo "================================================"
echo ""

# ============ CONFIGURACIÓN ============
SITIO="ilq"
CHUNK_SIZE=5000

# Rutas de archivos originales
EMAPPER_ORIGINAL="/home/claire/emapper2gbk/metagenomas/eggnog/${SITIO}_rpkg.emapper6.txt"
FNA="/home/claire/emapper2gbk/metagenomas/fna/${SITIO}_contigs.fasta.db.fna"
FAA="/home/claire/emapper2gbk/metagenomas/faa/${SITIO}_contigs.fasta.db.faa"

# Directorios de trabajo
WORK_DIR="/home/claire/emapper2gbk/chunks_${SITIO}"
CLEAN_DIR="$WORK_DIR/eggnog_clean"
CHUNKS_DIR="$WORK_DIR/eggnog_chunks"
GBK_DIR="$WORK_DIR/gbk_output"

# Archivo limpio
EMAPPER_CLEAN="$CLEAN_DIR/${SITIO}_clean.emapper.tsv"

# Script de limpieza
SCRIPT_LIMPIEZA="/home/claire/emapper2gbk/limpiar_eggnog.py"

# ============ CREAR DIRECTORIOS ============
mkdir -p "$CLEAN_DIR"
mkdir -p "$CHUNKS_DIR"
mkdir -p "$GBK_DIR"

echo "Directorios creados:"
echo "  Clean: $CLEAN_DIR"
echo "  Chunks: $CHUNKS_DIR"
echo "  GBK: $GBK_DIR"
echo ""

# ============ VERIFICAR ARCHIVOS ============
echo "Verificando archivos de entrada..."

if [ ! -f "$EMAPPER_ORIGINAL" ]; then
    echo "❌ ERROR: No existe $EMAPPER_ORIGINAL"
    exit 1
fi
echo "  ✓ eggnog: $(ls -lh $EMAPPER_ORIGINAL | awk '{print $5}')"

if [ ! -f "$FNA" ]; then
    echo "❌ ERROR: No existe $FNA"
    exit 1
fi
echo "  ✓ FNA: $(ls -lh $FNA | awk '{print $5}')"

if [ ! -f "$FAA" ]; then
    echo "❌ ERROR: No existe $FAA"
    exit 1
fi
echo "  ✓ FAA: $(ls -lh $FAA | awk '{print $5}')"

if [ ! -f "$SCRIPT_LIMPIEZA" ]; then
    echo "❌ ERROR: No existe script de limpieza $SCRIPT_LIMPIEZA"
    echo "   Por favor crea el archivo limpiar_eggnog.py primero"
    exit 1
fi
echo "  ✓ Script limpieza: OK"
echo ""

# ============ PASO 1: LIMPIEZA ============
echo "================================================"
echo "PASO 1: LIMPIANDO ARCHIVO EGGNOG"
echo "================================================"

if [ -f "$EMAPPER_CLEAN" ]; then
    echo "Advertencia: Ya existe archivo limpio"
    read -p "¿Regenerar? (s/n): " respuesta
    if [ "$respuesta" != "s" ]; then
        echo "Usando archivo limpio existente"
    else
        echo "Regenerando..."
        python3 "$SCRIPT_LIMPIEZA" "$EMAPPER_ORIGINAL" "$EMAPPER_CLEAN"
    fi
else
    echo "Ejecutando limpieza..."
    python3 "$SCRIPT_LIMPIEZA" "$EMAPPER_ORIGINAL" "$EMAPPER_CLEAN"
fi

if [ ! -f "$EMAPPER_CLEAN" ]; then
    echo "❌ ERROR: Falló la limpieza del archivo"
    exit 1
fi

echo ""
echo "Archivo limpio generado:"
echo "  Tamaño: $(ls -lh $EMAPPER_CLEAN | awk '{print $5}')"
echo "  Líneas: $(wc -l < $EMAPPER_CLEAN)"
echo ""

# Mostrar primeras líneas del archivo limpio
echo "Primeras 3 líneas del archivo limpio:"
head -n 3 "$EMAPPER_CLEAN"
echo ""

# ============ PASO 2: DIVISIÓN EN CHUNKS ============
echo "================================================"
echo "PASO 2: DIVIDIENDO EN CHUNKS"
echo "================================================"

# Contar líneas (excluyendo header)
TOTAL_LINES=$(tail -n +2 "$EMAPPER_CLEAN" | wc -l)
NUM_CHUNKS=$(( ($TOTAL_LINES + $CHUNK_SIZE - 1) / $CHUNK_SIZE ))

echo "Estadísticas:"
echo "  Líneas totales (sin header): $TOTAL_LINES"
echo "  Tamaño chunk: $CHUNK_SIZE"
echo "  Chunks esperados: $NUM_CHUNKS"
echo ""

# Extraer header
echo "Extrayendo header..."
head -n 1 "$EMAPPER_CLEAN" > "$CHUNKS_DIR/header.txt"

# Dividir archivo
echo "Dividiendo archivo..."
tail -n +2 "$EMAPPER_CLEAN" | split -l $CHUNK_SIZE -d -a 3 - "$CHUNKS_DIR/${SITIO}_chunk_"

# Agregar header a cada chunk
echo "Agregando header a chunks..."
chunk_count=0
for chunk_file in "$CHUNKS_DIR/${SITIO}_chunk_"*; do
    if [ -f "$chunk_file" ] && [ "$chunk_file" != "$CHUNKS_DIR/header.txt" ]; then
        temp_file="${chunk_file}.tmp"
        cat "$CHUNKS_DIR/header.txt" "$chunk_file" > "$temp_file"
        mv "$temp_file" "$chunk_file"
        ((chunk_count++))
    fi
done

echo "✓ Chunks generados: $chunk_count"
echo ""

# ============ PASO 3: GENERAR GBKs ============
echo "================================================"
echo "PASO 3: GENERANDO ARCHIVOS GBK"
echo "================================================"
echo ""

processed=0
failed=0
start_time=$(date +%s)

for chunk_file in "$CHUNKS_DIR/${SITIO}_chunk_"*; do
    if [ -f "$chunk_file" ] && [ "$chunk_file" != "$CHUNKS_DIR/header.txt" ]; then
        chunk_name=$(basename "$chunk_file")
        chunk_num=$(echo "$chunk_name" | grep -o '[0-9]\+$')
        gbk_output="$GBK_DIR/${SITIO}_${chunk_num}.gbk"
        
        # Saltar si ya existe el GBK
        if [ -f "$gbk_output" ] && [ -s "$gbk_output" ]; then
            echo "[$((processed + failed + 1))/$chunk_count] ⏭ Ya existe: $chunk_name (saltando)"
            ((processed++))
            continue
        fi
        
        echo "[$((processed + failed + 1))/$chunk_count] Procesando: $chunk_name"
        
        # Ejecutar emapper2gbk
        emapper2gbk genes \
    -fn "$FNA" \
    -fp "$FAA" \
    -a "$chunk_file" \
    -n "metagenome" \
    -o "$gbk_output" \
    --ete > /dev/null 2>&1

if [ $? -eq 0 ] && [ -f "$gbk_output" ] && [ -s "$gbk_output" ]; then
            
            if [ -f "$gbk_output" ]; then
                size=$(ls -lh "$gbk_output" | awk '{print $5}')
                echo "  ✓ Generado: $gbk_output ($size)"
                ((processed++))
            else
                echo "  ❌ ERROR: No se generó archivo GBK"
                ((failed++))
            fi
        else
            echo "  ❌ ERROR en emapper2gbk"
            ((failed++))
        fi
    fi
done

end_time=$(date +%s)
duration=$((end_time - start_time))

echo ""
echo "================================================"
echo "RESUMEN FINAL"
echo "================================================"
echo "Sitio: $SITIO"
echo "Chunks generados: $chunk_count"
echo "GBKs exitosos: $processed"
echo "GBKs fallidos: $failed"
echo "Tiempo total: ${duration}s"
echo ""
echo "Ubicaciones:"
echo "  Archivo limpio: $EMAPPER_CLEAN"
echo "  Chunks: $CHUNKS_DIR"
echo "  GBKs: $GBK_DIR"
echo ""

if [ $processed -gt 0 ]; then
    echo "✓ Proceso completado con éxito"
    echo ""
    echo "Siguiente paso:"
    echo "  Los GBKs en $GBK_DIR están listos para PathwayTools"
    echo "  Debes crear la estructura de carpetas para MPWT"
else
    echo "❌ No se generaron GBKs exitosamente"
    echo "   Revisa los errores arriba"
fi

echo ""
echo "Finalizado: $(date)"