
#!/usr/bin/env python3
"""
Limpia archivos eggnog de metagenomas eliminando columnas de abundancia.
"""

import sys
import argparse
from pathlib import Path

# Columnas estándar de eggNOG-mapper
COLUMNAS_ESTANDAR = [
    'query', 'seed_ortholog', 'evalue', 'score', 'eggNOG_OGs', 
    'max_annot_lvl', 'COG_category', 'Description', 'Preferred_name',
    'GOs', 'EC', 'KEGG_ko', 'KEGG_Pathway', 'KEGG_Module',
    'KEGG_Reaction', 'KEGG_rclass', 'BRITE', 'KEGG_TC',
    'CAZy', 'BiGG_Reaction', 'PFAMs'
]

def limpiar_eggnog(entrada, salida, verbose=True):
    entrada = Path(entrada)
    salida = Path(salida)
    
    if not entrada.exists():
        raise FileNotFoundError(f"No existe: {entrada}")
    
    salida.parent.mkdir(parents=True, exist_ok=True)
    
    if verbose:
        print(f"Limpiando: {entrada.name}")
        print(f"Salida: {salida}")
    
    lineas_procesadas = 0
    lineas_genes = 0
    indices_funcionales = None
    
    with open(entrada, 'r') as f_in, open(salida, 'w') as f_out:
        for linea in f_in:
            lineas_procesadas += 1
            
            # Primera línea = header
            if lineas_procesadas == 1:
                campos_header = linea.strip().split('\t')
                
                # Columnas 0 (gene_id) + 8 en adelante (funcionales)
                # Columnas 1-7 son abundancia
                indices_funcionales = [0]  # gene_id (query)
                indices_funcionales.extend(range(8, len(campos_header)))
                
                n_eliminadas = len(campos_header) - len(indices_funcionales)
                
                if verbose:
                    print(f"  Columnas totales: {len(campos_header)}")
                    print(f"  Columnas eliminadas: {n_eliminadas}")
                    print(f"  Columnas mantenidas: {len(indices_funcionales)}")
                
                # Escribir header estándar
                f_out.write('#' + '\t'.join(COLUMNAS_ESTANDAR) + '\n')
                continue
            
            if not linea.strip():
                continue
            
            # Parsear línea de gen
            campos = linea.strip().split('\t')
            
            # Extraer campos funcionales
            campos_limpios = [campos[i] if i < len(campos) else '-' 
                             for i in indices_funcionales]
            
            # Asegurar 21 columnas
            while len(campos_limpios) < 21:
                campos_limpios.append('-')
            campos_limpios = campos_limpios[:21]
            
            f_out.write('\t'.join(campos_limpios) + '\n')
            lineas_genes += 1
            
            if verbose and lineas_genes % 50000 == 0:
                print(f"  Procesados: {lineas_genes:,} genes")
    
    if verbose:
        print(f"✓ Completado: {lineas_genes:,} genes")

def main():
    parser = argparse.ArgumentParser(description='Limpia archivos eggnog')
    parser.add_argument('entrada', help='Archivo eggnog de entrada')
    parser.add_argument('salida', help='Archivo limpio de salida')
    parser.add_argument('-q', '--quiet', action='store_true')
    
    args = parser.parse_args()
    
    try:
        limpiar_eggnog(args.entrada, args.salida, verbose=not args.quiet)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
