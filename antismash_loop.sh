#!/bin/bash
set -euo pipefail                                    # stop on the first error

# ----------  user paths ----------
GENOMES_DIR="/data/Antismash_micorrhyza/input_antismash"                # contains .fna and .gff files for each genome
ANTISMASH_DIR="/data/Antismash_micorrhyza/output_antismash"
mkdir -p "$ANTISMASH_DIR"

# ----------  iterate over *.fna ----------
shopt -s nullglob

for fna_file in "$GENOMES_DIR"/*.fna; do
    [[ -e "$fna_file" ]] || { echo "No .fna files found."; break; }

    species_base=$(basename "${fna_file%.fna}")
    gff_file="$GENOMES_DIR/${species_base}.gff"

    if [[ ! -f "$gff_file" ]]; then
        echo "Warning: GFF file missing for $species_base — skipping."
        continue
    fi

    outdir="$ANTISMASH_DIR/${species_base}_antismash"
    log="$outdir/run.log"
    mkdir -p "$outdir"

    echo -e "\n[$(date +'%F %T')]  ▶  Running antiSMASH for $species_base"

    antismash \
	        "$fna_file" \
        --taxon fungi \
        --cpus 30 \
        --output-dir "$outdir" \
        --output-basename "$species_base" \
        --clusterhmmer \
        --tigrfam \
        --asf \
        --cc-mibig \
		--cb-general \
        --cb-knownclusters \
        --cb-subclusters \
        --pfam2go \
        --rre \
        --allow-long-headers \
		--no-abort-on-invalid-records \
        --logfile "$log" \
        -v \
		--genefinding-gff3 "$gff_file"

done

echo -e "\nAll antiSMASH jobs finished!"
