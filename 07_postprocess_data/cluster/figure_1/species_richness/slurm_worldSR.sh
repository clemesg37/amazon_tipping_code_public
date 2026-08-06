#!/bin/bash
#SBATCH --job-name=species_richness_birds
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --time=08:00:00
#SBATCH --mem=32G

# Load the R/terra environment required by your HPC here.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
srun Rscript "$SCRIPT_DIR/plot_global_SR_birds_parallel.R"
