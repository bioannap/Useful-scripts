#!/bin/bash

conda activate braker3
mkdir output_braker

singularity exec -B /data/tools \
 -B ${PWD}:${PWD} braker3.sif braker.pl --species=saxifraga \ #add --useexisting if you have already run braker with that species
--genome=S_tomb_removed_organelles.curated.fasta.masked \
--prot_seq=/data/tools/orthodb_Viridiplantae.fa \
--gff3 \
--workingdir=output_braker --threads=35 \
--busco_lineage=eudicots_odb10 \
--AUGUSTUS_CONFIG_PATH=/data/Stombeanensis/annotation/Braker3/Augustus_config \
--AUGUSTUS_BIN_PATH=/data/tools/BRAKER3/Augustus \
--AUGUSTUS_SCRIPTS_PATH=/data/tools/BRAKER3/Augustus/scripts
