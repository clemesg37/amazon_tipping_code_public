# 01a -- Historical ERA5 climate preprocessing

## Folder overview

This folder creates the historical monthly ERA5 climate baseline used throughout the pipeline. It converts daily temperature and precipitation data into land-only monthly climatologies for 1980--2014. These files are inputs to 01c and the downstream bioclimatic-variable and species-distribution-model steps.

## Scripts

- `cluster/1a_preprocess_ERA5.py`: production preprocessing of the complete ERA5 data.
- `cluster/create_subsample_of_ERA5_for_local_calculations.py`: creates small South America subsets for validation.
- `cluster/slurm_script.sh`: generic Slurm template for the production script; users supply their HPC-specific account, partition, and environment setup.
- `local/preprocess_ERA5_0_5.ipynb`: local validation notebook using only the bundled small files in `local/data/`.

## Important calculations

The production script combines daily `tas`, `tasmin`, `tasmax`, and `pr` files; normalizes longitude/latitude coordinates; converts temperature from K to degC and precipitation to mm/day; aggregates to monthly values; applies the ISIMIP land mask; and calculates the 1980--2014 monthly climatology. The local notebook checks units, land masking, and diagnostic plots; it does not create production inputs.

## Inputs

- `$AMAZON_DATA_DIR/raw/01_a_era5/`: daily 20CRv3-ERA5 NetCDF files and `countrymasks-binary_30arcmin.nc`.
- `local/data/`: bundled South America/2015 validation subset and land mask.

The complete ERA5 data are external and are not included in the repository.

## Outputs

- `$AMAZON_DATA_DIR/intermediate/01_a_historical/T_AMAZON_base_period_historic.nc`
- `$AMAZON_DATA_DIR/intermediate/01_a_historical/P_AMAZON_base_period_historic.nc`
- `$AMAZON_DATA_DIR/intermediate/01_a_historical/local_validation/`: optional small subsets.
- `$AMAZON_OUTPUT_DIR/01_a_historical/plots/`: diagnostic plots.
## Detailed input/output inventory

### Inputs

| Location | Data | Origin | Used by |
| --- | --- | --- | --- |
| `$AMAZON_DATA_DIR/raw/01_a_era5/20crv3-era5_obsclim_{pr,tas,tasmin,tasmax}_global_daily_*.nc` | Daily global ERA5 climate variables, 1961--2021 | External ERA5/ISIMIP input | `1a_preprocess_ERA5.py` |
| `$AMAZON_DATA_DIR/raw/01_a_era5/countrymasks-binary_30arcmin.nc` | 0.5-degree land mask | External ISIMIP input | `1a_preprocess_ERA5.py` |
| `local/data/` | 2015 South America validation subset and land mask | Created by the subset script; small copies included | Local notebook |

### Outputs

| Location | Data | Produced by | Used by |
| --- | --- | --- | --- |
| `$AMAZON_DATA_DIR/intermediate/01_a_historical/T_AMAZON_base_period_historic.nc` | Monthly 1980--2014 `Tavg`, `Tmin`, and `Tmax` climatology | `1a_preprocess_ERA5.py` | 01c, 02, 04, 05 |
| `$AMAZON_DATA_DIR/intermediate/01_a_historical/P_AMAZON_base_period_historic.nc` | Monthly 1980--2014 precipitation climatology | `1a_preprocess_ERA5.py` | 01c, 02 |
| `$AMAZON_DATA_DIR/intermediate/01_a_historical/local_validation/` | South America validation subsets | subset script | Local validation |
| `$AMAZON_OUTPUT_DIR/01_a_historical/plots/` | Belém diagnostic plots | production script | Quality control |