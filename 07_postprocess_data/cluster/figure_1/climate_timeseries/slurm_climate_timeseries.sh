#!/bin/bash
#SBATCH --job-name=figure1_climate_timeseries
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --time=04:00:00
#SBATCH --mem=32G

# Load the Python environment required by your HPC here.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
srun python "$SCRIPT_DIR/figure_1_plot_time_series_ET.py"
