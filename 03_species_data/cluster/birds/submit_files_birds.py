import os

# Template for slurm script
template = "slurm_species_data.sh"

# Define variables that should be passed to the slurm scripts

# For birds
#species_types = ["resident", "breeding", "non_breeding"]
species_types = ["non_breeding"]

# Number of parts per species type
# Resident: 50
# Breeding: 15
# Non Breeding: 15

parts = list(range(1,16))
#parts = [5]

# Define directory to save batch scripts
OUTPUT_ROOT = os.environ['AMAZON_OUTPUT_DIR']
batch_script_dir = os.path.join(OUTPUT_ROOT, '03_species_data', 'slurm', 'batch_scripts')
os.makedirs(batch_script_dir, exist_ok=True)

# Loop to create and submit batch script for each passed variable
for species_type in species_types:
    for i in parts:

        # Create Job name
        job_name = f"{species_type}_part_{i}"

        # Read SLURM-Template 
        with open(template, "r") as fileo:
            data = fileo.readlines()

        # Adjust relevant lines 
        for j, line in enumerate(data):
            if line.startswith("#SBATCH --job-name"):
                data[j] = f"#SBATCH --job-name={job_name}\n"
            elif line.startswith("#SBATCH --output"):
                data[j] = f"#SBATCH --output={OUTPUT_ROOT}/03_species_data/slurm/stdout/{job_name}-%j.out\n"
            elif line.startswith("#SBATCH --error"):
                data[j] = f"#SBATCH --error={OUTPUT_ROOT}/03_species_data/slurm/stderr/{job_name}-%j.err\n"

        # Adjust the last line at the end to pass the relevant vars to the R script
        data[-1] = f"srun -n 1 -u python select_bird_species_in_amazon_region.py {species_type} {i} \n"

        # Path for the new batch script
        newsubmit = os.path.join(batch_script_dir, f"{job_name}.sh")
        
        # Save the new slurm script
        with open(newsubmit, "w") as fileobject:
            fileobject.writelines(data)

        # Send the job
        os.system(f"sbatch {newsubmit}")
        print(f"Submitted job {job_name}")

