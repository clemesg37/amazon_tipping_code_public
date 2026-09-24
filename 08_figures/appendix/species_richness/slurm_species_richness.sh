#!/bin/bash
#SBATCH --time=08:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=1
#SBATCH --output=slurm-SRmean-%j.out
#SBATCH --error=slurm-SRmean-%j.err

# Generic example for calculating mean SR maps for one taxon.
# Submit, for example:
#   sbatch slurm_species_richness.sh amphibians
# Valid taxa: amphibians, mammals, reptiles, birds_resident
#
# Before submission, load or configure the R, terra, GDAL, and PROJ environment
# required on your HPC. This script deliberately contains no system-specific paths.

set -euo pipefail

SPECIES_TYPE="${1:?Usage: sbatch slurm_species_richness.sh <species_type>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${AMAZON_DATA_DIR:?Set AMAZON_DATA_DIR to the project data directory before submission.}"
: "${AMAZON_OUTPUT_DIR:?Set AMAZON_OUTPUT_DIR to the project artifact directory before submission.}"

# Example, adapted to the target HPC:
# module purge
# module load R GDAL PROJ GEOS

export AMAZON_DATA_DIR AMAZON_OUTPUT_DIR
Rscript --vanilla "$SCRIPT_DIR/calculate_mean_richness_cluster_per_species_type.R" "$SPECIES_TYPE"
