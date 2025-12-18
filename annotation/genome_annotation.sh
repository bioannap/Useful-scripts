#!/bin/bash

################################################################################
# Genome Annotation Pipeline
# RepeatModeler -> RepeatMasker -> BRAKER3
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

################################################################################
# CONFIGURATION VARIABLES - EDIT THESE FOR YOUR ANALYSIS
################################################################################

# Input genome file (unmasked)
GENOME_FILE="/data/Stombeanensis/assemblies/S_tomb_removed_organelles.curated.fasta"

# Species name (used for database naming and BRAKER)
SPECIES_NAME="saxifraga"

# Working directories
BASE_DIR="/data/Stombeanensis/annotation"
REPEATMODELER_DIR="${BASE_DIR}/RepeatModeler"
REPEATMASKER_DIR="${BASE_DIR}/RepeatMasker"
BRAKER_DIR="${BASE_DIR}/Braker3"

# RepeatModeler settings
RM_THREADS=40
RM_DATABASE="${SPECIES_NAME}_db"
ENABLE_LTRSTRUCT=true  # Set to false to skip LTR structuring (faster)

# RepeatMasker settings
RMASK_THREADS=30

# BRAKER3 settings
BRAKER_THREADS=35
BRAKER_SPECIES="${SPECIES_NAME}"
BUSCO_LINEAGE="eudicots_odb10"  # e.g., eudicots_odb10, fungi_odb10, vertebrata_odb10
PROTEIN_DB="/data/tools/orthodb_Viridiplantae.fa"
BRAKER_SINGULARITY="/path/to/braker3.sif"  # Path to BRAKER3 singularity image
USE_EXISTING=false  # Set to true if re-running BRAKER with same species

# Augustus paths
AUGUSTUS_CONFIG_PATH="${BRAKER_DIR}/Augustus_config"
AUGUSTUS_BIN_PATH="/data/tools/BRAKER3/Augustus"
AUGUSTUS_SCRIPTS_PATH="/data/tools/BRAKER3/Augustus/scripts"

# Conda environments
REPEATMASKER_ENV="RepeatMasker"
BRAKER_ENV="braker3"

# Log file
LOG_FILE="${BASE_DIR}/pipeline_$(date +%Y%m%d_%H%M%S).log"

################################################################################
# FUNCTIONS
################################################################################

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_file() {
    if [ ! -f "$1" ]; then
        log_message "ERROR: File not found: $1"
        exit 1
    fi
}

check_conda_env() {
    if ! conda env list | grep -q "^$1 "; then
        log_message "ERROR: Conda environment '$1' not found!"
        exit 1
    fi
}

################################################################################
# SCRIPT EXECUTION
################################################################################

log_message "=========================================="
log_message "Genome Annotation Pipeline Started"
log_message "=========================================="
log_message "Species: $SPECIES_NAME"
log_message "Genome file: $GENOME_FILE"
log_message "Base directory: $BASE_DIR"
log_message "=========================================="

# Check if genome file exists
check_file "$GENOME_FILE"

# Create directories
mkdir -p "$REPEATMODELER_DIR"
mkdir -p "$REPEATMASKER_DIR"
mkdir -p "$BRAKER_DIR"
mkdir -p "$AUGUSTUS_CONFIG_PATH"

################################################################################
# STEP 1: RepeatModeler - Build Repeat Library
################################################################################

log_message ""
log_message "=========================================="
log_message "STEP 1: RepeatModeler - Building Repeat Library"
log_message "=========================================="

# Activate RepeatMasker conda environment
eval "$(conda shell.bash hook)"
conda activate "$REPEATMASKER_ENV"

cd "$REPEATMODELER_DIR"

# Build database
log_message "Building BLAST database: ${RM_DATABASE}"
BuildDatabase -name "$RM_DATABASE" "$GENOME_FILE" 2>&1 | tee -a "$LOG_FILE"

# Run RepeatModeler
log_message "Running RepeatModeler with $RM_THREADS threads..."
if [ "$ENABLE_LTRSTRUCT" = true ]; then
    log_message "LTR structuring ENABLED (may take considerable time)"
    RepeatModeler -database "$RM_DATABASE" \
                  -threads "$RM_THREADS" \
                  -LTRStruct \
                  >& repeatmodeler_run.out &
    RM_PID=$!
    log_message "RepeatModeler running in background (PID: $RM_PID)"
    log_message "Monitoring progress (check repeatmodeler_run.out for details)..."
    wait $RM_PID
else
    log_message "LTR structuring DISABLED (faster analysis)"
    RepeatModeler -database "$RM_DATABASE" \
                  -threads "$RM_THREADS" \
                  >& repeatmodeler_run.out &
    RM_PID=$!
    log_message "RepeatModeler running in background (PID: $RM_PID)"
    wait $RM_PID
fi

# Check if repeat library was generated
REPEAT_LIBRARY="${RM_DATABASE}-families.fa"
if [ ! -f "$REPEAT_LIBRARY" ]; then
    log_message "ERROR: RepeatModeler did not generate repeat library!"
    exit 1
fi

log_message "RepeatModeler completed successfully!"
log_message "Repeat library: $REPEAT_LIBRARY"

################################################################################
# STEP 2: RepeatMasker - Soft Masking
################################################################################

log_message ""
log_message "=========================================="
log_message "STEP 2: RepeatMasker - Soft Masking Genome"
log_message "=========================================="

cd "$REPEATMASKER_DIR"

# Copy genome file to RepeatMasker directory (optional)
GENOME_BASENAME=$(basename "$GENOME_FILE")

log_message "Running RepeatMasker with custom library..."
RepeatMasker -pa "$RMASK_THREADS" \
             -gff \
             -xsmall \
             -lib "${REPEATMODELER_DIR}/${REPEAT_LIBRARY}" \
             -dir "$REPEATMASKER_DIR" \
             "$GENOME_FILE" 2>&1 | tee -a "$LOG_FILE"

# Check if masked file was generated
MASKED_GENOME="${REPEATMASKER_DIR}/${GENOME_BASENAME}.masked"
if [ ! -f "$MASKED_GENOME" ]; then
    log_message "ERROR: RepeatMasker did not generate masked genome!"
    exit 1
fi

log_message "RepeatMasker completed successfully!"
log_message "Masked genome: $MASKED_GENOME"

################################################################################
# STEP 3: BRAKER3 - Gene Prediction
################################################################################

log_message ""
log_message "=========================================="
log_message "STEP 3: BRAKER3 - Gene Prediction"
log_message "=========================================="

# Activate BRAKER conda environment
conda activate "$BRAKER_ENV"

cd "$BRAKER_DIR"

# Check if protein database exists
check_file "$PROTEIN_DB"

# Check if singularity image exists
check_file "$BRAKER_SINGULARITY"

# Prepare BRAKER command
BRAKER_CMD="singularity exec -B /data/tools -B ${PWD}:${PWD} $BRAKER_SINGULARITY braker.pl"
BRAKER_CMD="$BRAKER_CMD --species=$BRAKER_SPECIES"
BRAKER_CMD="$BRAKER_CMD --genome=$MASKED_GENOME"
BRAKER_CMD="$BRAKER_CMD --prot_seq=$PROTEIN_DB"
BRAKER_CMD="$BRAKER_CMD --gff3"
BRAKER_CMD="$BRAKER_CMD --workingdir=${BRAKER_DIR}/output_braker"
BRAKER_CMD="$BRAKER_CMD --threads=$BRAKER_THREADS"
BRAKER_CMD="$BRAKER_CMD --busco_lineage=$BUSCO_LINEAGE"
BRAKER_CMD="$BRAKER_CMD --AUGUSTUS_CONFIG_PATH=$AUGUSTUS_CONFIG_PATH"
BRAKER_CMD="$BRAKER_CMD --AUGUSTUS_BIN_PATH=$AUGUSTUS_BIN_PATH"
BRAKER_CMD="$BRAKER_CMD --AUGUSTUS_SCRIPTS_PATH=$AUGUSTUS_SCRIPTS_PATH"

if [ "$USE_EXISTING" = true ]; then
    BRAKER_CMD="$BRAKER_CMD --useexisting"
    log_message "Using --useexisting flag (reusing existing species parameters)"
fi

log_message "Running BRAKER3..."
log_message "Command: $BRAKER_CMD"

mkdir -p "${BRAKER_DIR}/output_braker"

# Run BRAKER3
eval $BRAKER_CMD 2>&1 | tee -a "$LOG_FILE"

# Check if BRAKER output exists
if [ ! -f "${BRAKER_DIR}/output_braker/braker.gtf" ]; then
    log_message "WARNING: braker.gtf not found. Check BRAKER output for errors."
else
    log_message "BRAKER3 completed successfully!"
    log_message "GTF file: ${BRAKER_DIR}/output_braker/braker.gtf"
fi

################################################################################
# PIPELINE COMPLETION
################################################################################

log_message ""
log_message "=========================================="
log_message "Pipeline Completed Successfully!"
log_message "=========================================="
log_message "Summary of outputs:"
log_message "1. Repeat library: ${REPEATMODELER_DIR}/${REPEAT_LIBRARY}"
log_message "2. Masked genome: $MASKED_GENOME"
log_message "3. BRAKER output: ${BRAKER_DIR}/output_braker/"
log_message "=========================================="
log_message "Log file saved to: $LOG_FILE"
log_message "=========================================="

conda deactivate
