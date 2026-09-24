#!/bin/bash
#SBATCH --job-name=sdm_species_richness_mean
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --time=08:00:00
#SBATCH --mem=32G

# Usage:
# sbatch slurm_species_richness.sh <ssp> <tip> <deforestation> <period>
# Calculates all-species mean and SD richness maps from 100 total MC maps.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
Rscript --vanilla "$SCRIPT_DIR/calculate_mean_richness_cluster.R" "$@"