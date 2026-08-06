#!/bin/bash

#SBATCH --qos=normal
#SBATCH --job-name=tipping_precipitation
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1

# Load and activate the Python environment available on your HPC.
# module load anaconda
# conda activate climatedata
#SBATCH --cpus-per-task=16
#SBATCH --time=02:00:00

srun -n 1 python -u process_moisture_network_evap_MC.py ssp245 tipping_climate_change