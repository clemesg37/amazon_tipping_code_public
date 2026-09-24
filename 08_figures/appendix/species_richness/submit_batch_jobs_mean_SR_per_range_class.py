from __future__ import annotations

import os
import subprocess
from pathlib import Path

def require_environment_path(name: str) -> Path:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"Set {name} before submitting jobs.")
    return Path(value)


DATA_ROOT = require_environment_path("AMAZON_DATA_DIR")
OUTPUT_ROOT = require_environment_path("AMAZON_OUTPUT_DIR")
SCRIPT_DIR = Path(__file__).resolve().parent

ARTIFACT_ROOT = (
    OUTPUT_ROOT
    / "08_figures"
    / "appendix"
    / "species_richness"
    / "range_class_mean"
    / "slurm"
)
BATCH_DIR = ARTIFACT_ROOT / "batch_scripts"
STDOUT_DIR = ARTIFACT_ROOT / "stdout"
STDERR_DIR = ARTIFACT_ROOT / "stderr"
for directory in (BATCH_DIR, STDOUT_DIR, STDERR_DIR):
    directory.mkdir(parents=True, exist_ok=True)

# Restrict this list for a targeted recovery run if necessary.
RANGE_SIZE_CLASSES = ["supersmall", "small", "medium", "large", "superlarge"]

MODULES = os.environ.get("AMAZON_HPC_MODULES")
if not MODULES:
    raise RuntimeError(
        "Set AMAZON_HPC_MODULES to the R/GDAL/PROJ/GEOS module list for the target HPC."
    )


def make_batch_script(job_name: str, command: str) -> Path:
    batch_path = BATCH_DIR / f"{job_name}.sh"
    batch_path.write_text(
        "\n".join(
            [
                "#!/bin/bash",
                "#SBATCH --qos=short",
                "#SBATCH --account=account_name",
                f"#SBATCH --job-name={job_name}",
                f"#SBATCH --output={STDOUT_DIR / (job_name + '-%j.out')}",
                f"#SBATCH --error={STDERR_DIR / (job_name + '-%j.err')}",
                "#SBATCH --time=08:00:00",
                "#SBATCH --mem=32G",
                "#SBATCH --cpus-per-task=1",
                f"#SBATCH --chdir={SCRIPT_DIR}",
                "",
                "set -euo pipefail",
                "module purge",
                f"module load {MODULES}",
                "",
                '# Optional system-specific GDAL/PROJ setup can be added here.',
                "",
                f'export AMAZON_DATA_DIR="{DATA_ROOT}"',
                f'export AMAZON_OUTPUT_DIR="{OUTPUT_ROOT}"',
                "",
                command,
                "",
            ]
        ),
        encoding="utf-8",
    )
    return batch_path


for range_class in RANGE_SIZE_CLASSES:
    job_name = f"SRmean_class_{range_class}"
    command = (
        f'Rscript --vanilla "{SCRIPT_DIR / "mean_SR_per_range_size_class.R"}" '
        f"{range_class}"
    )
    batch_script = make_batch_script(job_name, command)
    subprocess.run(["sbatch", str(batch_script)], check=True)
    print(f"Submitted {job_name}: {batch_script}")

