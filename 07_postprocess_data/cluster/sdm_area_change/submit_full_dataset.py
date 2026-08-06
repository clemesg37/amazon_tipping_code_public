import os
import subprocess
from pathlib import Path

OUTPUT_ROOT = Path(os.environ["AMAZON_OUTPUT_DIR"])
SCRIPT_DIR = Path(__file__).resolve().parent
JOB_NAME = "sdm_area_change"

artifact_dir = OUTPUT_ROOT / "07_postprocess_data" / "sdm_area_change" / "slurm"
batch_dir = artifact_dir / "batch_scripts"
stdout_dir = artifact_dir / "stdout"
stderr_dir = artifact_dir / "stderr"
for directory in (batch_dir, stdout_dir, stderr_dir):
    directory.mkdir(parents=True, exist_ok=True)

batch_script = batch_dir / f"{JOB_NAME}.sh"
batch_script.write_text(
    "\n".join([
        "#!/bin/bash",
        f"#SBATCH --job-name={JOB_NAME}",
        f"#SBATCH --output={stdout_dir / (JOB_NAME + '-%j.out')}",
        f"#SBATCH --error={stderr_dir / (JOB_NAME + '-%j.err')}",
        "#SBATCH --time=04:00:00",
        "#SBATCH --mem=32G",
        "# Load the required Python environment for your HPC here.",
        f"srun python {SCRIPT_DIR / 'create_full_dataset_area_change.py'}",
        "",
    ]),
    encoding="utf-8",
)
subprocess.run(["sbatch", str(batch_script)], check=True)
