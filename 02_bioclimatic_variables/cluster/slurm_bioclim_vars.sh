#!/bin/bash

# Add site-specific Slurm directives here if required (e.g., account, QoS, partition).
#SBATCH --job-name=bioclimatic_variables
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=16

# Load and activate the Python environment available on your HPC.
# module load anaconda
# conda activate climatedata

srun python -u calc_bioclim_vars_future.py ssp245 tip deforestation