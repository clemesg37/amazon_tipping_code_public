import os
from pathlib import Path
import geopandas as gpd
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import rioxarray
import xarray as xr
from matplotlib.colors import TwoSlopeNorm
from matplotlib.gridspec import GridSpec

DATA_ROOT = Path(os.environ["AMAZON_DATA_DIR"])
OUTPUT_ROOT = Path(os.environ["AMAZON_OUTPUT_DIR"])

# Select scenario.
ssp = "ssp245"

# Store reusable Figure 1 inputs as intermediate data and diagnostic plots as output artifacts.
data_out_dir = DATA_ROOT / "intermediate" / "07_postprocess_data" / "figure_1" / "climate_timeseries"
save_dir = OUTPUT_ROOT / "07_postprocess_data" / "figure_1" / "climate_timeseries" / "plots"
data_out_dir.mkdir(parents=True, exist_ok=True)
save_dir.mkdir(parents=True, exist_ok=True)

# Load Delta precipitation data.
Delta_P_NorESM_deforestation_path = (
    DATA_ROOT
    / "intermediate"
    / "01_b_precipitation_changes"
    / f"amazon_precip_ETresid_perc_changes_ssp_{ssp}_tipscenario_tipping_climate_change_deforestation_MC.nc"
)
Delta_P_NorESM = xr.open_dataset(Delta_P_NorESM_deforestation_path)

###### Load Data ######

# Load ERA5 data for Delta calculations.
base_year_dir = DATA_ROOT / "intermediate" / "01_a_historical"
T_ERA5_base_year_1980_2014 = xr.open_dataset(base_year_dir / "T_AMAZON_base_period_historic.nc")
P_ERA5_base_year_1980_2014 = xr.open_dataset(base_year_dir / "P_AMAZON_base_period_historic.nc")

# Select coordinates lat/lon coordinates of ERA5 data as target grid.
lat_coord_ERA5 = P_ERA5_base_year_1980_2014.latitude.values
lon_coord_ERA5 = P_ERA5_base_year_1980_2014.longitude.values

## 3) Interpolate precipitation data

Delta_P_NorESM = Delta_P_NorESM.assign_coords({
    "lat": ("coord", Delta_P_NorESM["lat"].values),
    "lon": ("coord", Delta_P_NorESM["lon"].values)
}).set_index(coord=("lat", "lon")).unstack("coord").rename({"lat": "latitude", "lon": "longitude"})

Delta_P_NorESM = Delta_P_NorESM.drop_vars("histpr")

# Add sample coordinates (1-100).
num_samples = Delta_P_NorESM.sizes["sample"]
sample_coords = np.arange(num_samples)
Delta_P_NorESM = Delta_P_NorESM.assign_coords(sample=("sample", sample_coords))

Delta_P_NorESM = Delta_P_NorESM.chunk({"sample": 1, "year": 10, "month": 12, "latitude": -1, "longitude": -1})

# Linear interpolation of Delta P to ERA5 grid (for the interior).
Delta_P_ERA5_linear = Delta_P_NorESM.interp(latitude=lat_coord_ERA5, longitude=lon_coord_ERA5, method="linear")
Delta_P_ERA5_linear = Delta_P_ERA5_linear.assign_coords(month=(Delta_P_ERA5_linear.month + 1))

# Nearest-neighbour interpolation of Delta P to ERA5 grid (for the edge).
Delta_P_ERA5_nearest = Delta_P_NorESM.interp(latitude=lat_coord_ERA5, longitude=lon_coord_ERA5, method="nearest")
Delta_P_ERA5_nearest = Delta_P_ERA5_nearest.assign_coords(month=(Delta_P_ERA5_nearest.month + 1))

# Replace missing linear-interpolation cells with nearest-neighbour values at the edge.
Delta_P_ERA5 = Delta_P_ERA5_linear.combine_first(Delta_P_ERA5_nearest)

Delta_P_ERA5["PC_CCTIP"] = Delta_P_ERA5["PC_CCTIP"].where(
    (Delta_P_ERA5["PC_CCTIP"] > -100) | (Delta_P_ERA5["PC_CCTIP"].isnull()),
    -99.99,
)

# Convert percentage to fraction.
Delta_P_ERA5 = Delta_P_ERA5 / 100

# Expand year dimension for base year values.
P_ERA5_base_year_1980_2014_expanded = P_ERA5_base_year_1980_2014.expand_dims(year=Delta_P_ERA5.year)

## 4) Create delta-corrected time series for precipitation.
P_delta_approach_time_series_PC_CC = (
    P_ERA5_base_year_1980_2014_expanded.pr * (1 + Delta_P_ERA5.PC_CC)
)
P_delta_approach_time_series_PC_CCTIP = (
    P_ERA5_base_year_1980_2014_expanded.pr * (1 + Delta_P_ERA5.PC_CCTIP)
)

# Annual totals.
P_no_tip_annual = P_delta_approach_time_series_PC_CC.sum(dim="month", skipna=False)
P_tip_annual = P_delta_approach_time_series_PC_CCTIP.sum(dim="month", skipna=False)

# Percent difference: (tip - no_tip) / no_tip * 100.
mask_zero = (P_no_tip_annual == 0) | P_no_tip_annual.isnull()
percent_diff = (P_tip_annual - P_no_tip_annual) / P_no_tip_annual * 100
percent_diff = percent_diff.where(~mask_zero)

# Select periods and means.
periods = {
    "2030-2044": (2030, 2044),
    "2050-2069": (2050, 2069),
    "2080-2099": (2080, 2099),
}

period_means = {}
for name, (start, end) in periods.items():
    sel = percent_diff.sel(year=slice(start, end))
    period_means[name] = sel.mean(dim=["sample", "year"], skipna=True).compute()

period_means_path = data_out_dir / "period_means.nc"
ds = xr.Dataset({name: da for name, da in period_means.items()})
ds.to_netcdf(period_means_path)

# Color range.
maps = list(period_means.values())
all_vals = np.concatenate([m.values.ravel() for m in maps])
all_vals = all_vals[np.isfinite(all_vals)]
vmin = float(np.nanmin(all_vals))
vmax = -vmin
norm = TwoSlopeNorm(vmin=vmin, vcenter=0.0, vmax=vmax)
cmap = "RdBu"

# Time series precipitation.
ts_no_tip = P_no_tip_annual.mean(dim=["latitude", "longitude"])
ts_tip_sample = (
    P_tip_annual
    .mean(dim=["latitude", "longitude"])
    .chunk({"sample": -1})
)
ts_tip_ci_low = ts_tip_sample.quantile(0.025, dim="sample")
ts_tip_ci_high = ts_tip_sample.quantile(0.975, dim="sample")
ts_tip_mean = ts_tip_sample.mean(dim="sample")

ts_no_tip_v = ts_no_tip.compute().values
ts_tip_mean_v = ts_tip_mean.compute().values
ts_tip_ci_low_v = ts_tip_ci_low.compute().values
ts_tip_ci_high_v = ts_tip_ci_high.compute().values
years = ts_no_tip.year.values

df = pd.DataFrame({
    "time": years,
    "ts_no_tip": ts_no_tip_v,
    "ts_tip": ts_tip_mean_v,
    "ts_tip_ci_low": ts_tip_ci_low_v,
    "ts_tip_ci_high": ts_tip_ci_high_v,
})
df.to_csv(data_out_dir / "precipitation_time_series_residET.csv", index=False)


