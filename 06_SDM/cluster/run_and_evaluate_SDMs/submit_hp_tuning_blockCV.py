import os
from pathlib import Path

OUTPUT_ROOT = Path(os.environ["AMAZON_OUTPUT_DIR"])
SCRIPT_DIR = Path(__file__).resolve().parent
TEMPLATE = SCRIPT_DIR / "slurm_template.sh"

# Select a manageable subgroup and index range for this run.
N_SPECIES_PER_BATCH = 1
SPECIES_TYPE = "birds_resident"
START_INDEX = 2
END_INDEX = 200

batch_script_dir = OUTPUT_ROOT / "06_sdm" / "slurm" / "batch_scripts"
stdout_dir = OUTPUT_ROOT / "06_sdm" / "slurm" / "stdout"
stderr_dir = OUTPUT_ROOT / "06_sdm" / "slurm" / "stderr"
for directory in (batch_script_dir, stdout_dir, stderr_dir):
    directory.mkdir(parents=True, exist_ok=True)

for start_index in range(START_INDEX, END_INDEX + 1, N_SPECIES_PER_BATCH):
    end_index = min(start_index + N_SPECIES_PER_BATCH - 1, END_INDEX)
    job_name = f"run_{SPECIES_TYPE}_{start_index}_to_{end_index}"
    data = TEMPLATE.read_text().splitlines(keepends=True)
    for index, line in enumerate(data):
        if line.startswith("#SBATCH --job-name"):
            data[index] = f"#SBATCH --job-name={job_name}\n"
        elif line.startswith("#SBATCH --output"):
            data[index] = f"#SBATCH --output={stdout_dir / f'{job_name}-%j.out'}\n"
        elif line.startswith("#SBATCH --error"):
            data[index] = f"#SBATCH --error={stderr_dir / f'{job_name}-%j.err'}\n"
    data[-1] = f"Rscript --vanilla {SCRIPT_DIR / 'cluster_tuning_HP_blockCV_projection_MCapproach_ETresid.R'} {start_index} {end_index} {SPECIES_TYPE}\n"
    newsubmit = batch_script_dir / f"{job_name}.sh"
    newsubmit.write_text("".join(data))
    os.system(f'sbatch "{newsubmit}"')
    print(f"Submitted job {job_name}")
