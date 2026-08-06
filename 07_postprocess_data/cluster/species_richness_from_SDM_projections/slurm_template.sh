#!/bin/bash
#SBATCH --job-name=sdm_species_richness
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --time=08:00:00
#SBATCH --mem=32G

# Load the R/terra environment required by your HPC here.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
Rscript --vanilla "$SCRIPT_DIR/calculate_richness_cluster_final.R <start_index> <end_index> <ssp> <tip> <deforestation> <period> <species_type>"
