import os
from pathlib import Path

OUTPUT_ROOT = Path(os.environ["AMAZON_OUTPUT_DIR"])
SCRIPT_DIR = Path(__file__).resolve().parent
TEMPLATE = SCRIPT_DIR / "slurm_template.sh"

# Number of species in each type and size class. Submit one manageable subgroup at a time.
SPECIES_COUNTS = {
    ("amphibians", "supersmall"): 47, ("amphibians", "small"): 51, ("amphibians", "medium"): 45, ("amphibians", "large"): 49, ("amphibians", "superlarge"): 18,
    ("mammals", "supersmall"): 87, ("mammals", "small"): 73, ("mammals", "medium"): 62, ("mammals", "large"): 69, ("mammals", "superlarge"): 92,
    ("reptiles", "supersmall"): 32, ("reptiles", "small"): 47, ("reptiles", "medium"): 44, ("reptiles", "large"): 79, ("reptiles", "superlarge"): 52,
    ("birds_resident", "supersmall"): 232, ("birds_resident", "small"): 200, ("birds_resident", "medium"): 199, ("birds_resident", "large"): 283, ("birds_resident", "superlarge"): 187,
}

# Edit these values to submit another taxon/size-class subgroup.
SPECIES_TYPE = "birds_resident"
CLASS_VALUE = "supersmall"
N_SPECIES_PER_BATCH = 50
END_INDEX = SPECIES_COUNTS[(SPECIES_TYPE, CLASS_VALUE)]

batch_script_dir = OUTPUT_ROOT / "05_selected_bioclimatic_variables" / "slurm" / "batch_scripts"
stdout_dir = OUTPUT_ROOT / "05_selected_bioclimatic_variables" / "slurm" / "stdout"
stderr_dir = OUTPUT_ROOT / "05_selected_bioclimatic_variables" / "slurm" / "stderr"
for directory in (batch_script_dir, stdout_dir, stderr_dir):
    directory.mkdir(parents=True, exist_ok=True)

for start_index in range(1, END_INDEX + 1, N_SPECIES_PER_BATCH):
    end_index = min(start_index + N_SPECIES_PER_BATCH - 1, END_INDEX)
    job_name = f"bioclim_selection_{CLASS_VALUE}_{SPECIES_TYPE}_{start_index}_to_{end_index}"
    data = TEMPLATE.read_text().splitlines(keepends=True)
    for index, line in enumerate(data):
        if line.startswith("#SBATCH --job-name"):
            data[index] = f"#SBATCH --job-name={job_name}\n"
        elif line.startswith("#SBATCH --output"):
            data[index] = f"#SBATCH --output={stdout_dir / f'{job_name}-%j.out'}\n"
        elif line.startswith("#SBATCH --error"):
            data[index] = f"#SBATCH --error={stderr_dir / f'{job_name}-%j.err'}\n"
    data[-1] = f"Rscript --vanilla {SCRIPT_DIR / 'select_bioclimatic_vars_for_species.R'} {start_index} {end_index} {SPECIES_TYPE} {CLASS_VALUE}\n"
    newsubmit = batch_script_dir / f"{job_name}.sh"
    newsubmit.write_text("".join(data))
    os.system(f'sbatch "{newsubmit}"')
    print(f"Submitted job {job_name}")
