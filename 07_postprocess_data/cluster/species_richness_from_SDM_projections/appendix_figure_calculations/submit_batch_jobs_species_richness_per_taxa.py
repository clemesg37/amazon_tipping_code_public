import os
import subprocess
from pathlib import Path

import numpy as np

OUTPUT_ROOT = Path(os.environ["AMAZON_OUTPUT_DIR"])
SCRIPT_DIR = Path(__file__).resolve().parent
ARTIFACT_ROOT = OUTPUT_ROOT / "07_postprocess_data" / "species_richness_from_SDM_projections" / "slurm"
BATCH_DIR = ARTIFACT_ROOT / "batch_scripts"
STDOUT_DIR = ARTIFACT_ROOT / "stdout"
STDERR_DIR = ARTIFACT_ROOT / "stderr"
for directory in (BATCH_DIR, STDOUT_DIR, STDERR_DIR):
    directory.mkdir(parents=True, exist_ok=True)


def submit(job_name, command):
    batch_script = BATCH_DIR / f"{job_name}.sh"
    batch_script.write_text(
        "\n".join([
            "#!/bin/bash",
            f"#SBATCH --job-name={job_name}",
            f"#SBATCH --output={STDOUT_DIR / (job_name + '-%j.out')}",
            f"#SBATCH --error={STDERR_DIR / (job_name + '-%j.err')}",
            "#SBATCH --time=08:00:00",
            "#SBATCH --mem=32G",
            "# Load the R/terra environment required by your HPC here.",
            command,
            "",
        ]),
        encoding="utf-8",
    )
    subprocess.run(["sbatch", str(batch_script)], check=True)

# Edit this list to submit only taxa required for the current run.
SELECTED_SPECIES_TYPES = ["amphibians", "reptiles", "mammals", "birds_resident"]
N_MC_SAMPLE_SPLITS = 10

for species_type in SELECTED_SPECIES_TYPES:
    for part in np.array_split(np.arange(1, 101), N_MC_SAMPLE_SPLITS):
        start_index, end_index = int(part[0]), int(part[-1])
        job_name = f"SR_{species_type}_{start_index}_{end_index}"
        command = f"Rscript --vanilla {SCRIPT_DIR / 'calculate_SR_by_taxa.R'} {species_type} {start_index} {end_index}"
        submit(job_name, command)
        print(f"Submitted {job_name}")
