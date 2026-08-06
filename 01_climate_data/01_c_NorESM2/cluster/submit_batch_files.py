import os
from pickle import TRUE 

# Template for slurm script
template = "slurm_preprocess.sh"

# Define variables that should be passed to the slurm scripts
ssps = ["ssp245", "ssp370"]
#ssps = ["ssp245"]
tipping = [True, False]
#tipping = [False]
deforestation = [True, False]
#deforestation = [False]

# Define directory to save batch scripts
OUTPUT_ROOT = os.environ['AMAZON_OUTPUT_DIR']
batch_script_dir = os.path.join(OUTPUT_ROOT, '01_c_NorESM2', 'slurm', 'batch_scripts')
os.makedirs(batch_script_dir, exist_ok=True)

# Loop to create and submit batch script for each passed variable
for ssp in ssps:
    for tip in tipping:

        defor_values = deforestation if tip else [False]

        for defor in defor_values:
            # Create job name
            job_name = f"Name_{ssp}_{tip}_{defor}"
            # Read slurm template
            with open(template, "r") as fileo:
                data = fileo.readlines()
            
            for j, line in enumerate(data):
                if line.startswith("#SBATCH --job-name"):
                    data[j] = f"#SBATCH --job-name={job_name}\n"
                elif line.startswith("#SBATCH --output"):
                    data[j] = f"#SBATCH --output={OUTPUT_ROOT}/01_c_NorESM2/slurm/stdout/{job_name}-%j.out\n"
                elif line.startswith("#SBATCH --error"):
                    data[j] = f"#SBATCH --error={OUTPUT_ROOT}/01_c_NorESM2/slurm/stderr/{job_name}-%j.err\n"

            # Adjust the last line at the end to pass relevant vars
            data[-1] = f"srun python -u 1c_preprocessing_NorESM_data_delta_approach.py {ssp} {tip} {defor} \n"

            # Path to the new batch script
            newsubmit = os.path.join(batch_script_dir, f"{job_name}.sh")

            # Save the new slurm script
            with open(newsubmit, "w") as fileobject:
                fileobject.writelines(data)
            
            # Send the job
            os.system(f'sbatch {newsubmit}')
            print(f"Submitted job {job_name}")


