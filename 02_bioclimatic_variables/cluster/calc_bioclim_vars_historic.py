from bioclimatic_variables_functions_historic import *
import xarray as xr
import os

DATA_ROOT = os.environ['AMAZON_DATA_DIR']

# Load base year datasets
T_base_year_path = f"{DATA_ROOT}/intermediate/01_a_historical/T_AMAZON_base_period_historic.nc"
P_base_year_path = f"{DATA_ROOT}/intermediate/01_a_historical/P_AMAZON_base_period_historic.nc"


T = xr.open_dataset(T_base_year_path)
P = xr.open_dataset(P_base_year_path)

# Calculate bioclimatic variables
bioclim_vars = calculate_bioclimatic_variables_historic(T, P)

#save_dir = f"{DATA_ROOT}/intermediate/02_bioclimatic_variables"

save_dir = f"{DATA_ROOT}/intermediate/02_bioclimatic_variables"
bioclim_vars.to_netcdf(f"{save_dir}/bioclimatic_variables_historic_ERA5_1980_2014.nc")
print(f"Bioclimatic variables calculated and saved under {save_dir}/bioclimatic_variables_historic_ERA5_1980_2014.nc")

