from bioclimatic_variables_functions_future import *
from bioclimatic_variables_functions_historic import *
import xarray as xr
import sys
import os

DATA_ROOT = os.environ['AMAZON_DATA_DIR']

# Define scenario 

# ssp 
ssp = sys.argv[1]

# tipping analysis
tip = sys.argv[2]

# deforestion 
deforestation = sys.argv[3]

# Load data sets based on ssp, tip and deforetation scenario
input_dir = f"{DATA_ROOT}/intermediate/01_c_noresm2/{ssp}/"
os.makedirs(input_dir, exist_ok=True)

# Directory to save bioclimatic variables
save_dir = f"{DATA_ROOT}/intermediate/02_bioclimatic_variables/{ssp}/"
os.makedirs(save_dir, exist_ok=True)

time_periods = [(2030, 2044), (2050, 2069), (2080, 2099)]

for (start_year, end_year) in time_periods:
    if tip == "tip":
        T_path = os.path.join(input_dir,f"tip/{deforestation}/T_monthly_ETresid_{start_year}_{end_year}.nc")
        P_path = os.path.join(input_dir,f"tip/{deforestation}/P_monthly_ETresid_{start_year}_{end_year}.nc")
        
        # Load dataset 
        T = xr.open_dataset(T_path)
        P = xr.open_dataset(P_path)

        # Calculate bioclimatic variables
        bioclim_vars = calculate_bioclimatic_variables_future(T, P)   

        # Save data 
        save_path = f"{save_dir}tip/{deforestation}/bioclim_vars_ETresid_{start_year}_{end_year}.nc"
        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        bioclim_vars.to_netcdf(save_path)  
        print(f"Bioclimatic variables saved under {save_path}.")
    else:
        T_path = os.path.join(input_dir,f"notip/T_monthly_ETresid_{start_year}_{end_year}.nc")
        P_path = os.path.join(input_dir,f"notip/P_monthly_ETresid_{start_year}_{end_year}.nc")

        # Load dataset 
        T = xr.open_dataset(T_path)
        P = xr.open_dataset(P_path)

        # Calculate bioclimatic variables
        bioclim_vars = calculate_bioclimatic_variables_historic(T, P) # Use historic, because no sampling dimension if no tipping analysis 

        # Save data 
        save_path = f"{save_dir}notip/bioclim_vars_ETresid_{start_year}_{end_year}.nc"
        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        bioclim_vars.to_netcdf(save_path) 
        print(f"Bioclimatic variables saved under {save_path}.")

