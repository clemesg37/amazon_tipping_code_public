#!/bin/bash

#SBATCH --qos=short
#SBATCH --job-name=amazon
#SBATCH --account=account_name
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err

#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=32

module load anaconda
source activate climatedata 

srun -n 1 python NordESM2_create_subsample_of_data_for_local_calculations.py