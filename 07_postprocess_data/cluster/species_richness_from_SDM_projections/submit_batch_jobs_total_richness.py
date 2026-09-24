"""Submit path-neutral total all-species richness aggregation jobs."""

from __future__ import annotations

import os
import shlex
import subprocess
from pathlib import Path

import numpy as np

try:
    DATA_ROOT = Path(os.environ["AMAZON_DATA_DIR"])
    OUTPUT_ROOT = Path(os.environ["AMAZON_OUTPUT_DIR"])
except KeyError as exc:
    raise RuntimeError("Set AMAZON_DATA_DIR and AMAZON_OUTPUT_DIR before submitting jobs.") from exc

SCRIPT_DIR = Path(__file__).resolve().parent
RESULTS_ROOT = (
    DATA_ROOT / "intermediate" / "07_postprocess_data"
    / "species_richness_from_SDM_projections" / "results_ETresid"
)
ARTIFACT_ROOT = (
    OUTPUT_ROOT / "07_postprocess_data" / "species_richness_from_SDM_projections"
    / "total_mc" / "slurm"
)
BATCH_DIR = ARTIFACT_ROOT / "batch_scripts"
STDOUT_DIR = ARTIFACT_ROOT / "stdout"
STDERR_DIR = ARTIFACT_ROOT / "stderr"

TAXA = ["amphibians", "mammals", "reptiles", "birds_resident"]
MAP_KINDS = ["historic", "future", "delta"]
SSPS = ["ssp245", "ssp370"]
TIPS = ["tip", "notip"]
DEFORESTATIONS = ["deforestation", "no_deforestation"]
TIME_PERIODS = ["2030_2044", "2050_2069", "2080_2099"]
N_MC_SPLITS = 5


def scenario_dir(ssp: str, tip: str, deforestation: str, period: str) -> Path:
    return RESULTS_ROOT / f"{ssp}_{tip}_{deforestation}" / period


def validate_taxon_outputs(directory: Path) -> None:
    missing = [
        directory / f"{kind}_species_richness_MC_{taxon}{mc_id}.tif"
        for taxon in TAXA
        for kind in MAP_KINDS
        for mc_id in range(1, 101)
        if not (directory / f"{kind}_species_richness_MC_{taxon}{mc_id}.tif").is_file()
    ]
    if missing:
        examples = "\n".join(str(path) for path in missing[:20])
        raise RuntimeError(
            f"Cannot aggregate total richness: {len(missing)} taxon-level MC map(s) "
            f"are missing in {directory}.\nFirst missing files:\n{examples}"
        )


def make_batch_script(job_name: str, arguments: list[str]) -> Path:
    """Write a generic Slurm script; add site-specific module setup if required."""
    batch_path = BATCH_DIR / f"{job_name}.sh"
    command = " ".join(
        [
            "Rscript", "--vanilla", shlex.quote(str(SCRIPT_DIR / "calculate_total_richness_per_mc.R")),
            *(shlex.quote(value) for value in arguments),
        ]
    )
    batch_path.write_text(
        "\n".join(
            [
                "#!/bin/bash",
                "#SBATCH --qos=short",
                f"#SBATCH --job-name={job_name}",
                f"#SBATCH --output={STDOUT_DIR / (job_name + '-%j.out')}",
                f"#SBATCH --error={STDERR_DIR / (job_name + '-%j.err')}",
                "#SBATCH --time=08:00:00",
                "#SBATCH --mem=32G",
                "#SBATCH --cpus-per-task=1",
                f"#SBATCH --chdir={SCRIPT_DIR}",
                "",
                "set -euo pipefail",
                "# Add site-specific module or environment activation commands here.",
                f"export AMAZON_DATA_DIR={shlex.quote(str(DATA_ROOT))}",
                f"export AMAZON_OUTPUT_DIR={shlex.quote(str(OUTPUT_ROOT))}",
                command,
                "",
            ]
        ),
        encoding="utf-8",
    )
    return batch_path


for directory in (BATCH_DIR, STDOUT_DIR, STDERR_DIR):
    directory.mkdir(parents=True, exist_ok=True)

for ssp in SSPS:
    for tip in TIPS:
        deforestation_values = DEFORESTATIONS if tip == "tip" else ["no_deforestation"]
        for deforestation in deforestation_values:
            for period in TIME_PERIODS:
                directory = scenario_dir(ssp, tip, deforestation, period)
                validate_taxon_outputs(directory)
                for mc_range in np.array_split(np.arange(1, 101), N_MC_SPLITS):
                    start_index, end_index = int(mc_range[0]), int(mc_range[-1])
                    job_name = f"SRtotal_{ssp}_{tip}_{deforestation}_{period}_{start_index}_{end_index}"
                    batch_script = make_batch_script(
                        job_name,
                        [str(start_index), str(end_index), ssp, tip, deforestation, period],
                    )
                    subprocess.run(["sbatch", str(batch_script)], check=True)
                    print(f"Submitted {job_name}: {batch_script}")