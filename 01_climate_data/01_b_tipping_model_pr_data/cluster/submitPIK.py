import os 
import numpy as np
import pandas as pd
import glob

def check_output(name):
	return()

template="slurm_template.sh"

ssps=['ssp245','ssp370']
tipscenarios=['tipping_climate_change_deforestation','tipping_climate_change']

for s, ssp in enumerate(ssps):
    for t, tipscenario in enumerate(tipscenarios):

        fileo=open(template,"r")
        data=fileo.readlines()
        fileo.close()

        #add running instructions
        data[2]="#SBATCH --qos=short \n"
        data[3]="#SBATCH --job-name=TIP_" + str(s) + "_" +str(t) + " \n"

        data[15]="srun -n 1 python -u process_moisture_network_evap_MC.py " + ssp + " " + tipscenario + ' \n'

        data[12]="#SBATCH --cpus-per-task=16 \n"
        data[13]='#SBATCH --time=02:00:00' + "\n"

        #save new submission script
        newsubmit='submission_scripts/TIP_' + str(s) + "_" +str(t) + ".sh"
        fileobjec=open(newsubmit,"w")
        fileobjec.writelines(data)
        fileobjec.close()
        print(newsubmit)	

        os.system("sbatch " + str(newsubmit))
        print('submit!')


