import xarray as xr
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import os

DATA_ROOT = os.environ['AMAZON_DATA_DIR']
OUTPUT_ROOT = os.environ['AMAZON_OUTPUT_DIR']

## Overview datasets:

# ds Datasets describe daily global climate data 
# T & P Datasets describe monthly global climate data
# T_base and P_base describe mean monthly temperature and precipitation values calculated for the time period 1980-2014
## 1): Load and combine raw data to a time series

# Base path
data_path = os.path.join(DATA_ROOT, "raw", "01_a_era5")
save_path = os.path.join(DATA_ROOT, "intermediate", "01_a_historical")
os.makedirs(save_path, exist_ok=True)

# Define path of raw data files
years = list(range(1961, 2022, 10))
files_pr = [os.path.join(data_path, f"20crv3-era5_obsclim_pr_global_daily_{y}_{y+9}.nc") for y in years if y+9 <= 2021]
files_tas = [os.path.join(data_path, f"20crv3-era5_obsclim_tas_global_daily_{y}_{y+9}.nc") for y in years if y+9 <= 2021]
files_tasmin = [os.path.join(data_path, f"20crv3-era5_obsclim_tasmin_global_daily_{y}_{y+9}.nc") for y in years if y+9 <= 2021]
files_tasmax = [os.path.join(data_path, f"20crv3-era5_obsclim_tasmax_global_daily_{y}_{y+9}.nc") for y in years if y+9 <= 2021]

# Load all datasets and combine them to one time series
ds_pr = xr.open_mfdataset(files_pr, combine="by_coords", chunks='auto')
ds_tas = xr.open_mfdataset(files_tas, combine="by_coords", chunks='auto')
ds_tasmin = xr.open_mfdataset(files_tasmin, combine="by_coords", chunks='auto')
ds_tasmax = xr.open_mfdataset(files_tasmax, combine="by_coords", chunks='auto')


## 2): Rename and reorder coordinates

# pr
ds_pr = ds_pr.rename({"lon": "longitude", "lat": "latitude"})
ds_pr["longitude"] = (ds_pr["longitude"] + 180) % 360 - 180
ds_pr = ds_pr.sortby(["longitude", "latitude"])

# tas
ds_tas = ds_tas.rename({"lon": "longitude", "lat": "latitude"})
ds_tas["longitude"] = (ds_tas["longitude"] + 180) % 360 - 180
ds_tas = ds_tas.sortby(["longitude", "latitude"])

# tasmin
ds_tasmin = ds_tasmin.rename({"lon": "longitude", "lat": "latitude"})
ds_tasmin["longitude"] = (ds_tasmin["longitude"] + 180) % 360 - 180
ds_tasmin = ds_tasmin.sortby(["longitude", "latitude"])

# tasmax
ds_tasmax = ds_tasmax.rename({"lon": "longitude", "lat": "latitude"})
ds_tasmax["longitude"] = (ds_tasmax["longitude"] + 180) % 360 - 180
ds_tasmax = ds_tasmax.sortby(["longitude", "latitude"])

## 3) Adjust units

# temperature: K -> °C
ds_tas["tas"] = ds_tas["tas"] - 273.15
ds_tasmin["tasmin"] = ds_tasmin["tasmin"] - 273.15
ds_tasmax["tasmax"] = ds_tasmax["tasmax"] - 273.15

# precipitation: kg/(m^2 s) -> mm/day
ds_pr["pr"] = ds_pr["pr"] * 86400

## 4) Calculate monthly means and sum

# monthly mean for temperature
Tavg = ds_tas.resample(time="ME").mean(keep_attrs=True)
Tmin = ds_tasmin.resample(time="ME").mean(keep_attrs=True)
Tmax = ds_tasmax.resample(time="ME").mean(keep_attrs=True)

# monthly sum of precipitation
pr = ds_pr.resample(time="ME").sum(keep_attrs=True)

# Combine variables in one dataset 
T = xr.Dataset({"Tavg": Tavg["tas"], "Tmin": Tmin["tasmin"], "Tmax": Tmax["tasmax"]})
P = xr.Dataset({"pr": pr["pr"]})


## 5) Cut out variables only defined on land

# Load binary mask from ISIMIP to define land area
country_mask_binary_path = os.path.join(data_path, "countrymasks-binary_30arcmin.nc") # resolution of 0.5°

# Load dataset
country_mask_binary = xr.open_dataset(country_mask_binary_path)

# Select land boarders of the world
world_mask_binary = country_mask_binary["m_world"]

# Rename lat and lon
world_mask_binary = world_mask_binary.rename({"lon": "longitude", "lat":"latitude"})

# Sort lat and lon
world_mask_binary = world_mask_binary.sortby(["longitude", "latitude"])


# Apply mask on temperature and precipitation data

# temperatur
T = T.where(world_mask_binary == 1)
# precipitation
P = P.where(world_mask_binary == 1)

# Save data sets
#T.to_netcdf(f"{save_path}T_monthly_1961_2021.nc")
#P.to_netcdf(f"{save_path}P_monthly_1961_2021.nc")

## 6) Create base year 1980-2014
base_start = 1980
base_end = 2014

T = T.sel(time=slice(f"{base_start}-01-01", f"{base_end}-12-31"))
P = P.sel(time=slice(f"{base_start}-01-01", f"{base_end}-12-31"))

T_base = T.groupby("time.month").mean("time")
P_base = P.groupby("time.month").mean("time")


# Save data
save_path_base_year = save_path
T_base.to_netcdf(os.path.join(save_path_base_year, "T_AMAZON_base_period_historic.nc"))
P_base.to_netcdf(os.path.join(save_path_base_year, "P_AMAZON_base_period_historic.nc"))


# To compare with WORLDCLIM
#base_start = 1970
#base_end = 2000

#T_WC = T.sel(time=slice(f"{base_start}-01-01", f"{base_end}-12-31"))
#P_WC = P.sel(time=slice(f"{base_start}-01-01", f"{base_end}-12-31"))

#T_base_WC = T_WC.groupby("time.month").mean("time")
#P_base_WC = P_WC.groupby("time.month").mean("time")

# Save data
#save_path_base_year = os.path.join(DATA_ROOT, "intermediate", "climate", "historical")
#T_base_WC.to_netcdf(f"{save_path_base_year}T_AMAZON_base_period_historic_1970_2000.nc")
#P_base_WC.to_netcdf(f"{save_path_base_year}P_AMAZON_base_period_historic_1970_2000.nc")

## 7. Backup checks

# Path for plots
plot_path = os.path.join(OUTPUT_ROOT, "01_a_historical", "plots")
os.makedirs(plot_path, exist_ok=True)


### 7.1 

# Consider data in Belem in the year 2010

# coordinates
lat_belem, lon_belem = -1.45, -48.74 
year = 2010

# select data (mean monthly data)
T_belem_2010 = T.sel(longitude=lon_belem, latitude=lat_belem, method="nearest").sel(time=slice(f"{year}-01-01", f"{year}-12-31"))
P_belem_2010 = P.sel(longitude=lon_belem, latitude=lat_belem, method="nearest").sel(time=slice(f"{year}-01-01", f"{year}-12-31"))
#belem_Tavg, belem_Tmin, belem_Tmax = T_belem_2015["Tavg"], T_belem_2015["Tmin"], T_belem_2015["Tmax"]
#belem_pr = P_belem_2015["pr"]

# select data (daily data)
ds_tas_belem_2010 = ds_tas.sel(longitude=lon_belem, latitude=lat_belem, method="nearest").sel(time=slice(f"{year}-01-01", f"{year}-12-31"))
ds_tasmin_belem_2010 = ds_tasmin.sel(longitude=lon_belem, latitude=lat_belem, method="nearest").sel(time=slice(f"{year}-01-01", f"{year}-12-31"))
ds_tasmax_belem_2010 = ds_tasmax.sel(longitude=lon_belem, latitude=lat_belem, method="nearest").sel(time=slice(f"{year}-01-01", f"{year}-12-31"))
ds_pr_belem_2010 = ds_pr.sel(longitude=lon_belem, latitude=lat_belem, method="nearest").sel(time=slice(f"{year}-01-01", f"{year}-12-31"))

# plot temperatur

plt.figure()
# Average Temperatur
plt.plot(T_belem_2010["time"], T_belem_2010["Tavg"], marker = "o", color="green", label="mean") #mean monthly
plt.plot(ds_tas_belem_2010["time"], ds_tas_belem_2010["tas"], color="green", alpha = 0.5) #daily 
# Min Temperautur
plt.plot(T_belem_2010["time"], T_belem_2010["Tmin"], marker = "o", color="blue", label="min")
plt.plot(ds_tasmin_belem_2010["time"], ds_tasmin_belem_2010["tasmin"], color="blue", alpha = 0.5)
# Max Temperatur
plt.plot(T_belem_2010["time"], T_belem_2010["Tmax"], marker = "o", color="red", label="max")
plt.plot(ds_tasmax_belem_2010["time"], ds_tasmax_belem_2010["tasmax"], color="red", alpha = 0.5)

plt.ylabel("Temperature (° C)")
plt.xlabel("Time")
plt.title(f"Temperature in Belem in {year}\n ERA5 data")

plt.savefig(os.path.join(plot_path, "belem_2010_temperatur.png"))

# plot summed monthly precipitation and daily 

months = pd.date_range(
    start=f"{year}-01-01",
    end=f"{year}-12-01",
    freq="MS"
)

fig, axes = plt.subplots(1, 2)

# daily 
axes[0].plot(ds_pr_belem_2010["time"], ds_pr_belem_2010["pr"], color="blue")
axes[0].set_title("Daily")
axes[0].set_xlabel("Month")
axes[0].set_xticks(months)
axes[0].set_ylabel("Precipitation [mm]")
axes[0].set_xticklabels(range(1,13))

# monthly average
axes[1].plot(P_belem_2010["time"], P_belem_2010["pr"], marker="o", color="blue")
axes[1].set_title("Monthly Summed")
axes[1].set_xlabel("Month")
axes[1].set_xticks(months)
axes[1].set_xticklabels(range(1,13))

fig.suptitle("Belem - Precipitation 2010", fontsize=14)

plt.savefig(os.path.join(plot_path, "belem_2010_precipitation.png"))
plt.close()

### 7.2 

# Checks of base year calculations for temperature
fig, axes = plt.subplots()

T_belem = T.sel(
    longitude=lon_belem, latitude=lat_belem, method="nearest"
)

for year in range(base_start, base_end+1):
    T_belem_year = T_belem.sel(time=slice(f"{year}-01-01", f"{year}-12-31")).assign_coords(month=T_belem.time.dt.month)
    axes.plot(T_belem_year["month"], T_belem_year["Tavg"], color="grey", alpha=0.3)

T_belem_base = T_base.sel(
    longitude=lon_belem, latitude=lat_belem, method="nearest"
)

axes.plot(T_belem_base["month"], T_belem_base["Tavg"], marker="o", color="red", label="Mean 1980-2014")
axes.set_ylabel("Temperature ° C]")
axes.set_xlabel("Month")
axes.set_title("Base year temperature in Belem")
axes.legend()
plt.savefig(os.path.join(plot_path, "belem_base_year_T.png"))

# Mean monthly temperature caclulated from T
T_belem_mean =  T.sel(longitude=lon_belem, latitude=lat_belem, method="nearest").groupby("time.month").mean("time").compute()
print(T_belem_mean.Tavg)

# Mean monthly temperature of base year dataset
T_belem_mean_base = T_base.sel(longitude=lon_belem, latitude=lat_belem, method="nearest").Tavg.compute()
print(T_belem_mean_base)

# Check if true
print(T_belem_mean.Tavg == T_belem_mean_base)

# Print values for average temperature in belem in january 
#T_belem_jan = T_belem.sel(time=T_belem.time.dt.month == 1).Tavg
#print(T_belem_jan)

# Checks of base year calculations for precipitation
fig, axes = plt.subplots()

P_belem = P.sel(
    longitude=lon_belem, latitude=lat_belem, method="nearest"
)

for year in range(base_start, base_end+1):
    P_belem_year = P_belem.sel(time=slice(f"{year}-01-01", f"{year}-12-31")).assign_coords(month=P_belem.time.dt.month)
    axes.plot(P_belem_year["month"], P_belem_year["pr"], color="grey", alpha=0.3)

P_belem_base = P_base.sel(
    longitude=lon_belem, latitude=lat_belem, method="nearest"
)

axes.plot(P_belem_base["month"], P_belem_base["pr"], marker="o", color="red", label="Mean 1980-2014")
axes.set_ylabel("Precipitation [mm]]")
axes.set_xlabel("Month")
axes.set_title("Base year precipitation in Belem")
axes.legend()
plt.savefig(os.path.join(plot_path, "belem_base_year_P.png"))

# Mean monthly temperature caclulated from T
P_belem_mean =  P.sel(longitude=lon_belem, latitude=lat_belem, method="nearest").groupby("time.month").mean("time").compute()
print(P_belem_mean.pr)

# Mean monthly temperature of base year dataset
P_belem_mean_base = P_base.sel(longitude=lon_belem, latitude=lat_belem, method="nearest").pr.compute()
print(P_belem_mean_base)

# Check if true
print(P_belem_mean == P_belem_mean_base)

