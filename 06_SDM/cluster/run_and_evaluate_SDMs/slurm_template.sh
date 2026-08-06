#!/bin/bash

# Add site-specific Slurm directives here if required (e.g., account, QoS, partition).
#SBATCH --job-name=amazon_sdm
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=64

# Load the R environment and packages available on your HPC.
# module load R

Rscript --vanilla cluster_tuning_HP_blockCV_projection_MCapproach_ETresid.R 1 1 birds_resident
