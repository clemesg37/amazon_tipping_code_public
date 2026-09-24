#!/bin/bash
#SBATCH --job-name=sdm_total_species_richness
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --time=08:00:00
#SBATCH --mem=32G

# Usage:
# sbatch slurm_total_richness.sh <start_index> <end_index> <ssp> <tip> <deforestation> <period>
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
Rscript --vanilla "$SCRIPT_DIR/calculate_total_richness_per_mc.R" "$@"