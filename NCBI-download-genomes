#!/bin/bash

#If you have a selected list of genomes you want to download from NCBI write them all in a list: genomes_list.txt
#It has to be structured in two columns, one containing the species name (without whitespaces), the other containing the NCBI accession of the genome.

# Define the output base directory
BASE_DIR="/data/path/to/output/dir" 

# Read the list and process each genome
while read species accession; do
    # Create the folder name
    folder_name="${species}"
    
    # Define paths
    output_zip="${BASE_DIR}/${folder_name}.zip"
    output_dir="${BASE_DIR}/${folder_name}"
    
    echo "Downloading genome for $species ($accession)..."

    # Download the genome from NCBI
    datasets download genome accession "$accession" --filename "$output_zip"

    # Create a directory and unzip files inside it
    mkdir -p "$output_dir"
    unzip -d "$output_dir" "$output_zip"

    echo "Downloaded and extracted to: $output_dir"
    echo "--------------------------------------------------"
done < genomes_list.txt  # Make sure your list is saved in this file
