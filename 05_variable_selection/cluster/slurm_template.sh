#!/bin/bash

# Add site-specific Slurm directives here if required (e.g., account, QoS, partition).
#SBATCH --job-name=bioclim_selection
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=1

# Load the R environment available on your HPC.
# module load R

Rscript --vanilla select_bioclimatic_vars_for_species.R 1 1 birds_resident supersmall
