import os
from pathlib import Path

DATA_ROOT = Path(os.environ["AMAZON_DATA_DIR"])
OUTPUT_ROOT = Path(os.environ["AMAZON_OUTPUT_DIR"])
SCRIPT_DIR = Path(__file__).resolve().parent

# Template for Slurm scripts
TEMPLATE = SCRIPT_DIR / "slurm_template.sh"

# Number of input GPKG parts produced in Folder 03 for each species type.
PARTS_BY_SPECIES_TYPE = {
    "amphibians": 50,
    "mammals": 28,
    "reptiles_part1": 24,
    "reptiles_part2": 23,
    "birds_resident": 50,
    "birds_breeding": 15,
    "birds_non_breeding": 15,
}

# Select only the groups to submit in this run. Change this list for a later subgroup.
SELECTED_SPECIES_TYPES = ["amphibians"]

batch_script_dir = OUTPUT_ROOT / "04_rasterized_species" / "slurm" / "batch_scripts"
stdout_dir = OUTPUT_ROOT / "04_rasterized_species" / "slurm" / "stdout"
stderr_dir = OUTPUT_ROOT / "04_rasterized_species" / "slurm" / "stderr"
for directory in (batch_script_dir, stdout_dir, stderr_dir):
    directory.mkdir(parents=True, exist_ok=True)

for species_type in SELECTED_SPECIES_TYPES:
    number_of_parts = PARTS_BY_SPECIES_TYPE[species_type]
    for part in range(1, number_of_parts + 1):
        job_name = f"{species_type}_part_{part}"
        data = TEMPLATE.read_text().splitlines(keepends=True)

        for index, line in enumerate(data):
            if line.startswith("#SBATCH --job-name"):
                data[index] = f"#SBATCH --job-name={job_name}\n"
            elif line.startswith("#SBATCH --output"):
                data[index] = f"#SBATCH --output={stdout_dir / f'{job_name}-%j.out'}\n"
            elif line.startswith("#SBATCH --error"):
                data[index] = f"#SBATCH --error={stderr_dir / f'{job_name}-%j.err'}\n"

        data[-1] = f"Rscript --vanilla {SCRIPT_DIR / 'rasterize_species.R'} {species_type} {part}\n"
        newsubmit = batch_script_dir / f"{job_name}.sh"
        newsubmit.write_text("".join(data))

        os.system(f'sbatch "{newsubmit}"')
        print(f"Submitted job {job_name}")
