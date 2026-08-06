import xarray as xr
import os
import glob
import numpy as np
import matplotlib.pyplot as plt
import sys
import rioxarray 
import sys

# Select scenario

# Select ssp
ssp = sys.argv[1]

# Including tipping analysis or without tipping analysis (in Nicos model)
tip = sys.argv[2].lower() == "true" 

# With deforestation or without deforestation"
deforestation = sys.argv[3].lower() == "true"


###### Load Data ######

DATA_ROOT = os.environ['AMAZON_DATA_DIR']
OUTPUT_ROOT = os.environ['AMAZON_OUTPUT_DIR']

# Load ERA5 Data for Delta calculations
save_path_base_year = f"{DATA_ROOT}/intermediate/01_a_historical/"
T_ERA5_base_year_1980_2014 = xr.open_dataset(f"{save_path_base_year}T_AMAZON_base_period_historic.nc")
P_ERA5_base_year_1980_2014 = xr.open_dataset(f"{save_path_base_year}P_AMAZON_base_period_historic.nc")

# Load Delta precipitation data with residual evapotranspiration
if deforestation:
    Delta_P_NorESM_path = f"{DATA_ROOT}/intermediate/01_b_precipitation_changes/amazon_precip_ETresid_perc_changes_ssp_{ssp}_tipscenario_tipping_climate_change_deforestation_MC.nc"
else:
    Delta_P_NorESM_path = f"{DATA_ROOT}/intermediate/01_b_precipitation_changes/amazon_precip_ETresid_perc_changes_ssp_{ssp}_tipscenario_tipping_climate_change_MC.nc"

Delta_P_NorESM = xr.open_dataset(Delta_P_NorESM_path)

###### Step 1: Create temperature base year 1980-2014 for NorESM ######

# Define the base year range
base_start = 1980
base_end = 2014

# Path to historical data
data_dir = f"{DATA_ROOT}/raw/noresm2/historical/tas"

## 1) Load and combine all nc files

# Find matching NetCDF files
tas_files = sorted(glob.glob(os.path.join(data_dir, "*.nc")))

# Open and combine datasets
ds = xr.open_mfdataset(tas_files, combine="by_coords")

## 2) Clean and sort variables, select time period

# Drop unneeded boundary variables
ds = ds.drop_vars(["time_bnds", "lat_bnds", "lon_bnds"], errors="ignore")

# Convert longitudes from 0–360 to -180–180
ds['lon'] = ((ds['lon'] + 180) % 360) - 180
ds = ds.sortby(['lon', 'lat'])

# Rename to standard naming
ds = ds.rename({'lat': 'latitude', 'lon': 'longitude'})

# Transpose dimensions
ds = ds.transpose("time", "latitude", "longitude")

# Select time range for base period
ds = ds.sel(time=slice(f"{base_start}-01-01", f"{base_end}-12-31"))

# Extract variable and rename
Tavg = ds['tas']
Tavg.name = "Tavg"

## 3) Calculate base year for time period 1980-2014 

# Group by calendar month and compute mean over years
base_year = Tavg.groupby("time.month").mean("time")

# Wrap in dataset
T_NorESM_base_year_1980_2014 = xr.Dataset({"Tavg": base_year})

## 4) Backup checks

# Basics information 
#print("\n--- Base Year Dataset Info ---")
#print(T_NorESM_base_year_1980_2014)

#print("\n--- Value Range (Kelvin) ---")
#print(f"Min: {float(T_NorESM_base_year_1980_2014.Tavg.min().values):.2f} K")
#print(f"Max: {float(T_NorESM_base_year_1980_2014.Tavg.max().values):.2f} K")

# Plot (comment: only for the plot transform to ° C. The base year T_base should be in K.)

# Cologne 
cologne_T_base= T_NorESM_base_year_1980_2014.sel(latitude=50.9375, longitude=6.9603, method='nearest')

# Transform Temperature from Kelvin to Celsius and plot
cologne_T_base['Tavg'] = cologne_T_base['Tavg'] - 273.15

plt.figure(figsize=(10,5))
plt.title('Monthly Mean Temperature 1980-2014 in Cologne')
plt.ylabel('Temperature (°C)')
plt.xlabel('Month')

# Plot additional for each year the monthly mean as time series calculated from the climate_data before taking the mean
for year in range(1980, 2015):
    yearly_data = ds.sel(time=slice(f'{year}-01-01', f'{year}-12-31'))
    monthly_mean = yearly_data['tas'].groupby('time.month').mean('time') - 273.15
    plt.plot(monthly_mean['month'], monthly_mean.sel(latitude=50.9375, longitude=6.9603, method='nearest'), label=str(year), color='gray', alpha=0.5)

# Plot base year
plt.plot(T_NorESM_base_year_1980_2014['month'], cologne_T_base['Tavg'], marker='o', color='red', label='1980-2014 Mean')


# plot path for backup checks
plot_path = f"{OUTPUT_ROOT}/01_c_NorESM2/plots"

#plt.savefig(os.path.join(plot_path, "base_year_1980_2014_cologne.png"))

## 5) Save data

# Define output path
output_dir = f"{DATA_ROOT}/intermediate/01_c_noresm2/base_year"
os.makedirs(output_dir, exist_ok=True)

output_file = os.path.join(output_dir, "T_Tavg_base_year_monthly_1980_2014.nc")

# Save the base year dataset
#T_NorESM_base_year_1980_2014.to_netcdf(output_file)

print(f"Finish step 1: Saved base year dataset to {output_file}")


###### Step 2: Create future temperature time series 2015-2100 from NorESM model ######

# Define the time range
start_year = 2015
end_year = 2100

# Path to the NetCDF files
data_dir = f"{DATA_ROOT}/raw/noresm2/{ssp}/tas"

## 1) Load and combine all nc files

# Get all matching NetCDF files
tas_files = sorted(glob.glob(os.path.join(data_dir, "*.nc")))

# Open and combine the datasets
ds = xr.open_mfdataset(tas_files, combine="by_coords")

## 2) Clean and sort variables, select time period

# Drop boundary variables that are not needed
ds = ds.drop_vars(["time_bnds", "lat_bnds", "lon_bnds"], errors="ignore")

# Convert longitudes from 0–360 to -180–180
ds['lon'] = ((ds['lon'] + 180) % 360) - 180
ds = ds.sortby(['lon', 'lat'])

# Rename dimensions to standard naming
ds = ds.rename({'lat': 'latitude', 'lon': 'longitude'})

# Transpose to get dimensions in standard order
ds = ds.transpose("time", "latitude", "longitude")

# Select the time range of interest
ds = ds.sel(time=slice(f"{start_year}-01-01", f"{end_year}-12-31"))

# Define Tavg
Tavg = ds['tas']

# Rename variable to Tavg
Tavg.name = "Tavg"

# Create a new dataset with the processed variable
T_NorESM = xr.Dataset({"Tavg": Tavg})
T_NorESM = T_NorESM.chunk({"time": 30, "latitude": -1, "longitude": -1}) 

## 3) Backup Checks
#print("\n--- Dataset Info ---")
#print(T_NorESM)

#print("\n--- Time Range ---")
#print(f"Start: {str(T_NorESM.time.values[0])}")
#print(f"End:   {str(T_NorESM.time.values[-1])}")
#print(f"Total months: {T_NorESM.dims['time']}")

#print("\n--- Value Range (Kelvin) ---")
#print(f"Min: {float(T_NorESM.Tavg.min().values):.2f} K")
#print(f"Max: {float(T_NorESM.Tavg.max().values):.2f} K")

# Plot time series for cologne

# Select data near cologne
cologne_T = T_NorESM.sel(latitude=50.9375, longitude=6.9603, method='nearest')

# transfrom temperature from kelvin to celcius and plot
cologne_T["Tavg"] = cologne_T["Tavg"] - 273.15

# Select only part of the time series
#cologne_T = cologne_T.where(cologne_T.time.dt.year < 2020, drop=True)

# Calculate additionaly a daily mean
cologne_T_annual_mean = cologne_T["Tavg"].groupby("time.year").mean("time")

plt.figure(figsize=(15,5))
#cologne_T["Tavg"].plot(x="time")
plt.plot(cologne_T_annual_mean["year"], cologne_T_annual_mean)
plt.xlabel("Year")
plt.ylabel("Temperature (° C)")
plt.title(f"Annual mean temperature Cologne {ssp}")

# plot path for backup checks
plot_path = f"{OUTPUT_ROOT}/01_c_NorESM2/plots"
plt.savefig(os.path.join(plot_path, f"{ssp}_time_series_2015_2100_cologne_tavg.png"))

## 4) Save time series 

# Define output path
output_dir = f"{DATA_ROOT}/intermediate/01_c_noresm2/{ssp}/"
os.makedirs(output_dir, exist_ok=True)

output_file = os.path.join(output_dir, f"T_Tavg_{ssp}_NorESM2-MM_monthly_{start_year}_{end_year}.nc")

# Save the dataset to NetCDF
#T_NorESM.to_netcdf(output_file)

print(f"Finish Step 2: Saved result to {output_file}")

###### Step 3: Apply delta approach to obtain downscaled and biascorrected timeseries ######

## 1) Calculate Delta T for NorESM Data

# Create an array that has as values numbers 1-12 and as coordinates the time stemps of each year
months = T_NorESM["time"].dt.month

#  Add time as a coordinate of the base year
T_NorESM_base_year_1980_2014 = T_NorESM_base_year_1980_2014.sel(month=months)
T_NorESM_base_year_1980_2014 = T_NorESM_base_year_1980_2014.drop_vars("month")

# Calculate Delta value
Delta_T_NorESM = T_NorESM - T_NorESM_base_year_1980_2014

# Bring Delta values in the form dim = (year, month, latitude, longitude)
years = Delta_T_NorESM["time"].dt.year.data
months = Delta_T_NorESM["time"].dt.month.data   

Delta_T_NorESM = Delta_T_NorESM.assign_coords(year=("time", years), month=("time", months)).set_index(time=["year", "month"]).unstack("time").transpose("year", "month", "latitude", "longitude")

## 2) Interpolate temperature data

# Select coordinates lat/lon coordinates of ERA5 data as target grid
lat_coord_ERA5 = T_ERA5_base_year_1980_2014.latitude.values
lon_coord_ERA5 = T_ERA5_base_year_1980_2014.longitude.values

# Try different chuncks
Delta_T_NorESM = Delta_T_NorESM.chunk({"year": 1})

# Interpolate Delta T NorESM values on ERA5 grid
Delta_T_ERA5_interp = Delta_T_NorESM.interp(latitude=lat_coord_ERA5, longitude=lon_coord_ERA5, method="linear")

#print(Delta_T_ERA5_interp)

## 3) Interpolate precipitation data

# Bring P Delta dataset in the form dim = (year, month, latitude, longitude)
Delta_P_NorESM = Delta_P_NorESM.assign_coords({
    "lat": ("coord", Delta_P_NorESM["lat"].values),
    "lon": ("coord", Delta_P_NorESM["lon"].values)
}).set_index(coord=("lat", "lon")).unstack("coord").rename({"lat":"latitude", "lon":"longitude"})

# Drop the histpr variable (since it is not necessary for the delta calcualtions anymore)
Delta_P_NorESM = Delta_P_NorESM.drop_vars("histpr")

#print(Delta_P_NorESM)
#v0 = Delta_P_NorESM.sel(year=2030, month=1).isel(sample=1).PC_CC.max().compute().item()
#v1 = Delta_P_NorESM.sel(year=2030, month=1).isel(sample=2).PC_CC.max().compute().item()
#print(f"Sample 0 max: {v0}")
#print(f"Sample 1 max: {v1}")


# Add sample coordinates (0-99)
num_samples = Delta_P_NorESM.dims["sample"] # Should be 100
sample_coords = np.arange(num_samples)  
Delta_P_NorESM = Delta_P_NorESM.assign_coords(sample=("sample", sample_coords))

Delta_P_NorESM = Delta_P_NorESM.chunk({"sample": 1, "year": 10, "month": 12, "latitude": -1, "longitude": -1})

# Linear interpolation of Delta P to ERA5 grid (for the interior)
Delta_P_ERA5_linear = Delta_P_NorESM.interp(latitude=lat_coord_ERA5, longitude=lon_coord_ERA5, method="linear")
Delta_P_ERA5_linear = Delta_P_ERA5_linear.assign_coords(month=(Delta_P_ERA5_linear.month + 1))

# Nearest Neigbhour interpolation of Delta P to ERA5 grid (for the edge)
Delta_P_ERA5_nearest = Delta_P_NorESM.interp(latitude=lat_coord_ERA5, longitude=lon_coord_ERA5, method="nearest")
Delta_P_ERA5_nearest = Delta_P_ERA5_nearest.assign_coords(month=(Delta_P_ERA5_nearest.month + 1))

# Replace all cells of Delta_P_ERA5_nearest by Delta_P_ERA5_linear (in this way the edges kept at the nearest values)
Delta_P_ERA5 = Delta_P_ERA5_linear.combine_first(Delta_P_ERA5_nearest)

Delta_P_ERA5["PC_CCTIP"] = Delta_P_ERA5["PC_CCTIP"].where(
    (Delta_P_ERA5["PC_CCTIP"] > -100) | (Delta_P_ERA5["PC_CCTIP"].isnull()),
    -99.99
)


# Select amazon mask for SDMs (later)
#mask = xr.where(~np.isnan(Delta_P_ERA5["PC_CCTIP"]).isel(year=0, month=0, sample=0), 1, np.nan)

#lat_min, lat_max = -60, 15
#lon_min, lon_max = -90, -30
#mask_south_america = mask.sel(latitude=slice(lat_min, lat_max), longitude=slice(lon_min, lon_max))
#mask_south_america = mask_south_america.rio.write_crs("EPSG:4326", inplace=False)
#output_dir = "amazon_mask"
#os.makedirs(output_dir, exist_ok=True)

# 5) Save as GeoTIFF
#output_file = os.path.join(output_dir, "amazon_mask.tif")
#mask_south_america.rio.to_raster(output_file)

# Convert percentage to fraction
Delta_P_ERA5 = Delta_P_ERA5 / 100

# Expand year dimension for base year values to make calculation with delta values possibe
P_ERA5_base_year_1980_2014_expanded = P_ERA5_base_year_1980_2014.expand_dims(year=Delta_P_ERA5.year) 

## 4) Create delta corrected time series of temperature and precipitation

# Apply the delta approach for all grid cells inside the amazon region (where Delta_P got values) 
# All other values stay the same

P_delta_approach_time_series_PC_CC = xr.where(
    Delta_P_ERA5.PC_CC.notnull(),
    P_ERA5_base_year_1980_2014_expanded.pr + P_ERA5_base_year_1980_2014_expanded.pr * Delta_P_ERA5.PC_CC,
    P_ERA5_base_year_1980_2014_expanded.pr
)

P_delta_approach_time_series_PC_CCTIP = xr.where(
    Delta_P_ERA5.PC_CCTIP.notnull(),
    P_ERA5_base_year_1980_2014_expanded.pr + P_ERA5_base_year_1980_2014_expanded.pr * Delta_P_ERA5.PC_CCTIP,
    P_ERA5_base_year_1980_2014_expanded.pr
)

## Backup check: Delta approach precipitation

# coordinates
point_lat = -3.1
point_lon = -75.0

P_time_series_point_PC_CC = P_delta_approach_time_series_PC_CC.sel(
    latitude=point_lat, longitude=point_lon, method="nearest").sel(year=2080) 

P_time_series_point_PC_CCTIP = P_delta_approach_time_series_PC_CCTIP.sel(
    latitude=point_lat, longitude=point_lon, method="nearest").sel(year=2080, sample=1) 

P_base_year_point = P_ERA5_base_year_1980_2014_expanded.sel(
    latitude=point_lat, longitude=point_lon, method="nearest").sel(year=2080) 

fig = plt.figure(figsize=(10,6))
plt.plot(P_time_series_point_PC_CC["month"], P_time_series_point_PC_CC, marker="o", label="bias corrected TS CC")
plt.plot(P_time_series_point_PC_CCTIP["month"], P_time_series_point_PC_CCTIP, marker="o", label="bias corrected TS CC TIP")
plt.plot(P_base_year_point["month"], P_base_year_point.pr, marker="x", label="historical pr")
plt.xlabel("Month")
plt.ylabel("Precipitation (mm)")
plt.legend()
plt.title("Precipitation at selected location (2080)")
plt.savefig(f"{OUTPUT_ROOT}/01_c_NorESM2/plots/delta_approach_precipitation_2080_{ssp}_deforestation_{deforestation}.png")

# Check if delta approach worked locally

P_value_point_ts = P_time_series_point_PC_CCTIP.sel(month=5).compute().item()

P_value_point_delta_calculation = P_base_year_point.sel(month=5).pr.compute().item() +  P_base_year_point.sel(month=5).pr.compute().item() * Delta_P_ERA5.PC_CCTIP.sel(
    latitude= point_lat, longitude= point_lon, method="nearest").sel(year=2080, month=5, sample=1).compute().item()

print("Does the delta approach works (precipitation)?")
print(P_value_point_ts == P_value_point_delta_calculation)

# Create a delta dataset for the temperature data which is only defined in the amazon region
# and is NaN otherwise

# Mask (True in amazon basin)
mask_valid = ~Delta_P_ERA5.PC_CC.isnull().all(dim=("year", "month"))

# Set all values to NaN outside of amazon basin
Delta_T_ERA5_interp = Delta_T_ERA5_interp.where(mask_valid)

# Expand the year dimension of base year to match with delta values
T_ERA5_base_year_1980_2014_expanded = T_ERA5_base_year_1980_2014.expand_dims(year= Delta_T_ERA5_interp.year)

# Apply the delta approach in the amzon region and keep values outside of it
T_delta_approach_time_series = xr.where(
    Delta_T_ERA5_interp.notnull(),
    T_ERA5_base_year_1980_2014_expanded.Tavg + Delta_T_ERA5_interp,
    T_ERA5_base_year_1980_2014_expanded.Tavg
)

## coordinates
point_lat = -3.1
point_lon = -60

T_time_series_point = T_delta_approach_time_series.sel(
    latitude=point_lat, longitude=point_lon, method="nearest").sel(year=2060) 

T_base_year_point = T_ERA5_base_year_1980_2014_expanded.sel(
    latitude=point_lat, longitude=point_lon, method="nearest").sel(year=2060) 

fig = plt.figure(figsize=(10,6))
plt.plot(T_time_series_point["month"], T_time_series_point.Tavg, marker="o", label="bias corrected TS CC")
plt.plot(T_base_year_point["month"], T_base_year_point.Tavg, marker ="x", label="historical pr")
plt.xlabel("Month")
plt.ylabel("Temperature (° C)")
plt.legend()
plt.title("Temperature at selected location (2060)")
plt.savefig(f"{OUTPUT_ROOT}/01_c_NorESM2/plots/delta_approach_temperature_2060_{ssp}.png")

## Backup check 
T_value_point_ts = T_time_series_point.Tavg.sel(month=5).compute().item()
T_value_point_delta_calculation = T_base_year_point.sel(month=5).Tavg.compute().item() + Delta_T_ERA5_interp.sel(
    latitude=point_lat, longitude=point_lon, method="nearest").sel(year=2060, month=5).Tavg.compute().item()

print("Does the delta approach works (temperature)?")
print(T_value_point_ts == T_value_point_delta_calculation)

# Save
save_path_time_serie_folder = f"{DATA_ROOT}/intermediate/01_c_noresm2/bias_corrected_T_and_P/{ssp}/"

if tip:
    if deforestation:
        T_output_file = os.path.join(save_path_time_serie_folder, f"tip/deforestation/T_bias_corrected_ETresid.nc")
        P_output_file = os.path.join(save_path_time_serie_folder, f"tip/deforestation/P_bias_corrected_mean_ETresid.nc")
    else:
        T_output_file = os.path.join(save_path_time_serie_folder, f"tip/no_deforestation/T_bias_corrected_ETresid.nc")
        P_output_file = os.path.join(save_path_time_serie_folder, f"tip/no_deforestation/P_bias_corrected_mean_ETresid.nc")
    
    os.makedirs(os.path.dirname(T_output_file), exist_ok=True)
    T_delta_approach_time_series.to_netcdf(T_output_file)
    P_delta_approach_time_series_PC_CCTIP.mean(dim="sample").to_netcdf(P_output_file)
else:
    T_output_file = os.path.join(save_path_time_serie_folder, f"notip/T_bias_corrected_ETresid.nc")
    P_output_file = os.path.join(save_path_time_serie_folder, f"notip/P_bias_corrected_ETresid.nc")
    
    os.makedirs(os.path.dirname(T_output_file), exist_ok=True)
    T_delta_approach_time_series.to_netcdf(T_output_file)
    P_delta_approach_time_series_PC_CC.to_netcdf(P_output_file)

print(f"T and P time series saved for the {ssp} under {T_output_file} and {P_output_file}")

## 5) Calculate year average for time periods

# Define relevant time periods
time_periods = [(2030, 2044), (2050, 2069), (2080, 2099)]

for (start_year, end_year) in time_periods:
    
    # Slice time periodes
    T_delta_approach_time_series_subset = T_delta_approach_time_series.sel(year=slice(start_year, end_year))
    P_delta_approach_time_series_subset_PC_CC = P_delta_approach_time_series_PC_CC.sel(year=slice(start_year, end_year))
    P_delta_approach_time_series_subset_PC_CCTIP = P_delta_approach_time_series_PC_CCTIP.sel(year=slice(start_year, end_year))
    
    # Calculate mean over years
    T_mean = T_delta_approach_time_series_subset.mean(dim="year")
    P_PC_CC_mean = P_delta_approach_time_series_subset_PC_CC.mean(dim="year")
    P_PC_CCTIP_mean = P_delta_approach_time_series_subset_PC_CCTIP.mean(dim="year")

    # Save
    if tip:
        if deforestation:
            T_output_file = os.path.join(output_dir, f"tip/deforestation/T_monthly_ETresid_{start_year}_{end_year}.nc")
            P_output_file = os.path.join(output_dir, f"tip/deforestation/P_monthly_ETresid_{start_year}_{end_year}.nc")
        else:
            T_output_file = os.path.join(output_dir, f"tip/no_deforestation/T_monthly_ETresid_{start_year}_{end_year}.nc")
            P_output_file = os.path.join(output_dir, f"tip/no_deforestation/P_monthly_ETresid_{start_year}_{end_year}.nc")
        
        os.makedirs(os.path.dirname(T_output_file), exist_ok=True)
        T_mean.to_netcdf(T_output_file)
        P_PC_CCTIP_mean.to_netcdf(P_output_file)
    else:
        T_output_file = os.path.join(output_dir, f"notip/T_monthly_ETresid_{start_year}_{end_year}.nc")
        P_output_file = os.path.join(output_dir, f"notip/P_monthly_ETresid_{start_year}_{end_year}.nc")
        
        os.makedirs(os.path.dirname(T_output_file), exist_ok=True)
        T_mean.to_netcdf(T_output_file)
        P_PC_CC_mean.to_netcdf(P_output_file)

print(f"T and P period averages saved for the {ssp} scenario under {T_output_file} and {P_output_file}")

    

