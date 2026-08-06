#!/bin/bash

# Add site-specific Slurm directives here if required (e.g., account, QoS, partition).
#SBATCH --job-name=rasterize_species
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=1

# Load the R environment available on your HPC.
# module load R

Rscript --vanilla rasterize_species.R amphibians 1
