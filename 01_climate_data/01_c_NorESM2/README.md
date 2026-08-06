# 01c -- NorESM2 delta-approach climate preprocessing

## Folder overview

This folder applies the delta approach to combine the historical ERA5 baseline, NorESM2-MM temperature simulations, and precipitation-change ensembles from 01b. It creates future monthly climate data and period means for step 02.

## Scripts

- `cluster/1c_preprocessing_NorESM_data_delta_approach.py`: production calculation for one SSP, tipping, and deforestation combination.
- `cluster/submit_batch_files.py`: generates and submits Slurm jobs for all scenario combinations.
- `cluster/slurm_preprocess.sh`: generic Slurm template used by the submission script.
- `cluster/NordESM2_create_subsample_of_data_for_local_calculations.py`: creates reduced validation subsets.

## Important calculations

The production script calculates NorESM2 temperature anomalies relative to its historical baseline, interpolates temperature and precipitation changes to the ERA5 grid, applies these changes to the ERA5 baseline, and produces monthly time series plus average climate years for 2030--2044, 2050--2069, and 2080--2099. Tipping precipitation retains its Monte Carlo sample dimension; no-tipping calculations retain the deterministic scenario.

## Inputs

- `$AMAZON_DATA_DIR/intermediate/01_a_historical/`: ERA5 historical temperature and precipitation climatologies from 01a.
- `$AMAZON_DATA_DIR/intermediate/01_b_precipitation_changes/`: precipitation-change ensembles from 01b.
- `$AMAZON_DATA_DIR/raw/01_c_noresm2/historical/tas/` and `$AMAZON_DATA_DIR/raw/01_c_noresm2/<ssp>/tas/`: raw NorESM2-MM temperature files.

## Outputs

- `$AMAZON_DATA_DIR/intermediate/01_c_noresm2/`: bias-corrected monthly temperature and precipitation, including period means and validation subsets.
- `$AMAZON_OUTPUT_DIR/01_c_NorESM2/plots/`: diagnostic plots.
- `$AMAZON_OUTPUT_DIR/01_c_NorESM2/slurm/`: generated batch scripts and job logs.

## Local validation

`local/data/` contains small reference subsets for validation only. It is not a replacement for the full production inputs.
## Detailed input/output inventory

### Inputs

| Location | Data | Origin | Used by |
| --- | --- | --- | --- |
| `$AMAZON_DATA_DIR/intermediate/01_a_historical/T_AMAZON_base_period_historic.nc` | Historical ERA5 monthly temperature climatology | 01a | Delta approach |
| `$AMAZON_DATA_DIR/intermediate/01_a_historical/P_AMAZON_base_period_historic.nc` | Historical ERA5 monthly precipitation climatology | 01a | Delta approach |
| `$AMAZON_DATA_DIR/intermediate/01_b_precipitation_changes/amazon_precip_*.nc` | Tipping-model precipitation-change ensembles | 01b | Delta approach |
| `$AMAZON_DATA_DIR/raw/01_c_noresm2/historical/tas/*.nc` | Historical NorESM2-MM temperatures | External CMIP6 input | Temperature baseline |
| `$AMAZON_DATA_DIR/raw/01_c_noresm2/<ssp>/tas/*.nc` | Future NorESM2-MM temperatures | External CMIP6 input | Future temperature anomaly |

### Outputs

| Location | Data | Produced by | Used by |
| --- | --- | --- | --- |
| `$AMAZON_DATA_DIR/intermediate/01_c_noresm2/base_year/T_Tavg_base_year_monthly_1980_2014.nc` | NorESM2 historical monthly temperature baseline | Production script | Delta calculation/validation |
| `$AMAZON_DATA_DIR/intermediate/01_c_noresm2/<ssp>/` | Bias-corrected temperature and precipitation time series and period means | Production script | 02 |
| `$AMAZON_DATA_DIR/intermediate/01_c_noresm2/local_validation/` | Reduced climate and precipitation subsets | subset script | Local validation |
| `$AMAZON_OUTPUT_DIR/01_c_NorESM2/plots/` | Scenario-specific diagnostic plots | Production script | Quality control |
| `$AMAZON_OUTPUT_DIR/01_c_NorESM2/slurm/` | Generated batch scripts, standard output, and error logs | submission workflow | Cluster reproducibility |