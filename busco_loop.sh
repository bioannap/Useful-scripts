#!/bin/bash

# Directory where the .fasta files are located within subdirectories
DIRECTORY="/cluster/home/P10/genomes/"

# Directory where BUSCO output will be saved
OUTPUT_DIR="/cluster/home/P10/busco_output"

module load busco

# Fixed parameters for BUSCO execution
BUSCO_SCRIPT="busco"
#If you already have a the busco luneeahe saved somewhere put the absoute path of the directory, otherwise just enter the lineage you want
LINEAGE="/cluster/home/BUSCO_runs/busco_downloads/lineages/fungi_odb10"
MODE="genome"
CPU=8

# Find .fna files recursively and execute BUSCO for each
find "$DIRECTORY" -type f -name "*_genomic.fna" | while read -r FILE; do
    # Get the full directory path of the fasta file
    PARENT_DIR=$(dirname "$FILE")

    # Extract only the 'Prefix_name_species' directory from the path
    PREFIX_NAME_SPECIES=$(basename "$(dirname "$PARENT_DIR")") 

    # Define output directory with SCB_ prefix
    OUTPUT="SCB_${PREFIX_NAME_SPECIES}"

    echo "Executing BUSCO for $FILE..."
    $BUSCO_SCRIPT -i "$FILE" -o "$OUTPUT" -l "$LINEAGE" -m "$MODE" -c "$CPU"
    echo "Finished: $FILE"
    echo "---------------------------------------------"
done
