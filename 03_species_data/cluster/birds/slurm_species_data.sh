#!/bin/bash

# Add site-specific Slurm directives here if required.
#SBATCH --job-name=species_data
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=16

# Load and activate the Python environment available on your HPC.
# module load anaconda
# conda activate geospatial

srun python -u select_species_in_amazon_region.py amphibians 1