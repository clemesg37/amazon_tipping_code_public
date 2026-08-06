import os
import subprocess
from pathlib import Path

OUTPUT_ROOT = Path(os.environ["AMAZON_OUTPUT_DIR"])
SCRIPT_DIR = Path(__file__).resolve().parent
BATCH_SCRIPT_DIR = OUTPUT_ROOT / "07_postprocess_data" / "figure_1" / "species_richness" / "slurm" / "batch_scripts"
STDOUT_DIR = OUTPUT_ROOT / "07_postprocess_data" / "figure_1" / "species_richness" / "slurm" / "stdout"
STDERR_DIR = OUTPUT_ROOT / "07_postprocess_data" / "figure_1" / "species_richness" / "slurm" / "stderr"

# Choose a manageable subgroup before submission. The list may be changed without modifying the calculation script.
SELECTED_SPECIES_TYPES = ["mammals", "reptiles_part1", "reptiles_part2"]

for directory in (BATCH_SCRIPT_DIR, STDOUT_DIR, STDERR_DIR):
    directory.mkdir(parents=True, exist_ok=True)

for species_type in SELECTED_SPECIES_TYPES:
    job_name = f"SR_{species_type}"
    batch_script = BATCH_SCRIPT_DIR / f"{job_name}.sh"
    batch_script.write_text(
        "\n".join([
            "#!/bin/bash",
            f"#SBATCH --job-name={job_name}",
            f"#SBATCH --output={STDOUT_DIR / (job_name + '-%j.out')}",
            f"#SBATCH --error={STDERR_DIR / (job_name + '-%j.err')}",
            "#SBATCH --time=08:00:00",
            "#SBATCH --mem=32G",
            "# Load the R/terra environment required by your HPC here.",
            f"srun Rscript {SCRIPT_DIR / 'plot_global_SR_parallel.R'} {species_type}",
            "",
        ]),
        encoding="utf-8",
    )
    subprocess.run(["sbatch", str(batch_script)], check=True)
