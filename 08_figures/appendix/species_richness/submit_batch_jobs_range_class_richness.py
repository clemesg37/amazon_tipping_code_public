from __future__ import annotations

import os
import subprocess
from pathlib import Path

import numpy as np

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
    / "range_class_mc"
    / "slurm"
)
BATCH_DIR = ARTIFACT_ROOT / "batch_scripts"
STDOUT_DIR = ARTIFACT_ROOT / "stdout"
STDERR_DIR = ARTIFACT_ROOT / "stderr"
for directory in (BATCH_DIR, STDOUT_DIR, STDERR_DIR):
    directory.mkdir(parents=True, exist_ok=True)

# Edit these lists for a targeted test or recovery run.
RANGE_SIZE_CLASSES = ["supersmall", "small", "medium", "large", "superlarge"]
SSPS = ["ssp245", "ssp370"]
TIPS = ["tip", "notip"]
DEFORESTATIONS = ["deforestation", "no_deforestation"]
TIME_PERIODS = ["2030_2044", "2050_2069", "2080_2099"]
N_MC_SPLITS = 2

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
    for ssp in SSPS:
        for tip in TIPS:
            deforestation_values = DEFORESTATIONS if tip == "tip" else ["no_deforestation"]
            for deforestation in deforestation_values:
                for period in TIME_PERIODS:
                    for mc_range in np.array_split(np.arange(1, 101), N_MC_SPLITS):
                        start_index, end_index = int(mc_range[0]), int(mc_range[-1])
                        job_name = (
                            f"SRclass_{range_class}_{ssp}_{tip}_{deforestation}_"
                            f"{period}_{start_index}_{end_index}"
                        )
                        command = (
                            f'Rscript --vanilla "{SCRIPT_DIR / "calculate_SR_by_range_class.R"}" '
                            f"{start_index} {end_index} {ssp} {tip} "
                            f"{deforestation} {period} {range_class}"
                        )
                        batch_script = make_batch_script(job_name, command)
                        subprocess.run(["sbatch", str(batch_script)], check=True)
                        print(f"Submitted {job_name}: {batch_script}")



