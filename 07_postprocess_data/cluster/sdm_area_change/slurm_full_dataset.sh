#!/bin/bash
#SBATCH --job-name=sdm_area_change
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --time=04:00:00
#SBATCH --mem=32G

# Load the Python environment required by your HPC here.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
srun python "$SCRIPT_DIR/create_full_dataset_area_change.py"
