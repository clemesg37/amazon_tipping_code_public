import os
import xarray as xr

DATA_ROOT = os.environ["AMAZON_DATA_DIR"]
LOCAL_VALIDATION_DIR = f"{DATA_ROOT}/intermediate/01_c_noresm2/local_validation/"
os.makedirs(LOCAL_VALIDATION_DIR, exist_ok=True)

### Precipitation data
# Load data
precip_per_changes_path = f"{DATA_ROOT}/intermediate/01_b_precipitation_changes/amazon_precip_ETresid_perc_changes_ssp_ssp245_tipscenario_tipping_climate_change_MC.nc"
precip_per_changes = xr.open_dataset(precip_per_changes_path)

# Select only part of the data for local calculations
precip_per_changes_subsample = precip_per_changes.sel(year=slice(2050, 2070), sample=0)

# Save subdata
subdata_path = LOCAL_VALIDATION_DIR
precip_per_changes_subsample.to_netcdf(f"{subdata_path}subsample_amazon_precip_ETresid_perc_changes_ssp_ssp245_tipscenario_tipping_climate_change_MC.nc")

# Select T_avg time series
path_T_avg = f"{DATA_ROOT}/intermediate/01_c_noresm2/ssp245/T_Tavg_ssp245_NorESM2-MM_monthly_2015_2100.nc"

# Load dataset 
T_avg = xr.open_dataset(path_T_avg)

# Define subset
start_year = 2050
end_year = 2070

# Southamerica coordinates boaders
lon_min, lon_max = -90, -30
lat_min, lat_max = -60, 15

T_avg_subset = T_avg.sel(time=slice(f"{start_year}-01-01", f"{end_year}-12-31"))
T_avg_subset = T_avg_subset.sel(longitude=slice(lon_min, lon_max), latitude=slice(lat_min, lat_max))

print(T_avg_subset)

# Save subset
save_path_local_calculations = LOCAL_VALIDATION_DIR
T_avg_subset.to_netcdf(f"{save_path_local_calculations}T_avg_{start_year}_{end_year}_local.nc")


# Select subset of base year 
base_year_path =  f"{DATA_ROOT}/intermediate/01_c_noresm2/base_year/T_Tavg_base_year_monthly_1980_2014.nc"
T_base = xr.open_dataset(base_year_path)

# Select southamerica
T_base_southamerica = T_base.sel(longitude=slice(lon_min, lon_max), latitude=slice(lat_min, lat_max))

print(T_base_southamerica)

# Save subset
T_base_southamerica.to_netcdf(f"{save_path_local_calculations}T_base_southamerica_local.nc")



