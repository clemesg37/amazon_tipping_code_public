"""Create small South America subsets for local validation of step 01a."""

import os
from pathlib import Path

import xarray as xr

DATA_ROOT = Path(os.environ["AMAZON_DATA_DIR"])
RAW_ERA5_DIR = DATA_ROOT / "raw" / "era5"
HISTORICAL_DIR = DATA_ROOT / "intermediate" / "climate" / "historical"
LOCAL_VALIDATION_DIR = HISTORICAL_DIR / "local_validation"
LOCAL_VALIDATION_DIR.mkdir(parents=True, exist_ok=True)

# South America extent and validation year
LON_MIN, LON_MAX = -90, -30
LAT_MIN, LAT_MAX = -60, 15
YEAR = 2015


def subset_data(dataset: xr.Dataset, year: int) -> xr.Dataset:
    """Select South America and one validation year."""
    subset = dataset.sel(longitude=slice(LON_MIN, LON_MAX), latitude=slice(LAT_MIN, LAT_MAX))
    return subset.sel(time=slice(f"{year}-01-01", f"{year}-12-31"))


# Create subsets of daily ERA5 data.
years = list(range(1971, 2022, 10))
for variable in ("pr", "tas", "tasmin", "tasmax"):
    files = [
        RAW_ERA5_DIR / f"20crv3-era5_obsclim_{variable}_global_daily_{year}_{year + 9}.nc"
        for year in years
        if year + 9 <= 2021
    ]
    dataset = xr.open_mfdataset(files, combine="by_coords")
    dataset = dataset.rename({"lon": "longitude", "lat": "latitude"})
    dataset["longitude"] = (dataset["longitude"] + 180) % 360 - 180
    dataset = dataset.sortby(["longitude", "latitude"])
    subset_data(dataset, YEAR).to_netcdf(LOCAL_VALIDATION_DIR / f"{variable}_southamerica_{YEAR}.nc")

# Create South America subsets of the historical climatology produced by 1a_preprocess_ERA5.py.
for variable in ("T", "P"):
    input_path = HISTORICAL_DIR / f"{variable}_AMAZON_base_period_historic.nc"
    dataset = xr.open_dataset(input_path)
    subset = dataset.sel(longitude=slice(LON_MIN, LON_MAX), latitude=slice(LAT_MIN, LAT_MAX))
    subset.to_netcdf(LOCAL_VALIDATION_DIR / f"{variable}_southamerica_base_period_historic_local.nc")