#!/bin/bash

#RepeatModeler
#generate a species specific repeat library using the BLAST database
conda activate RepeatMasker
BuildDatabase -name saxifraga_db /data/Stombeanensis/assemblies/S_tomb_removed_organelles.curated.fasta

#Database is then used to build, refine, and classify consensus models of putative interspersed repeats with RECON and RepeatScout
#LTR structuring is really time consuming, you can omit that or give it a lot of cores.
RepeatModeler -database saxifraga_db -threads 40 -LTRStruct >& run.out &

#Repeatmasker softmasking
RepeatMasker -pa 30 -gff -xsmall -lib saxifraga_db-families.fa -dir /data/Stombeanensis/annotation/RepeatMasker /data/Stombeanensis/assemblies/S_tomb_removed_organelles.curated.fasta
