# 02 -- Bioclimatic variables

## Folder overview

This folder derives 14 bioclimatic variables from the historical ERA5 monthly climatology and the future, delta-corrected climate data produced in folder 01. The historical raster stack is used for SDM training; the scenario-specific future stacks are used for SDM projections. All production inputs and outputs are configured through `AMAZON_DATA_DIR`; Slurm artifacts are written under `AMAZON_OUTPUT_DIR` as described in [CONFIGURATION.md](../CONFIGURATION.md).

## Scripts

### Production code

- `cluster/calc_bioclim_vars_historic.py` loads the 1980--2014 ERA5 monthly climatology from 01a, calls the historical functions, and writes one historic raster stack.
- `cluster/calc_bioclim_vars_future.py`: runs once for each `ssp`, `tip`, and `deforestation` combination. It reads the three future periods from 01c and writes one bioclimatic-variable stack per scenario and period. Tipping-scenario input files contain Monte Carlo precipitation samples; no-tipping input files do not.
- `cluster/bioclimatic_variables_functions_historic.py` defines calculations for climate datasets with dimensions `(month, latitude, longitude)`.
- `cluster/bioclimatic_variables_functions_future.py` defines calculations for tipping scenarios. Temperature has dimensions `(month, latitude, longitude)`; delta-corrected absolute precipitation has dimensions `(sample, month, latitude, longitude)`.
- `cluster/submit_batch_scripts.py` creates and submits the Slurm jobs for all combinations of SSP, tipping status, and deforestation status.
- `cluster/slurm_bioclim_vars.sh` is the generic Slurm template used by the submission script. Site-specific account, partition, and environment commands remain commented placeholders.

### Local validation

- `local/backup_checks/local_calculate_historic_bioclimatic_variables.ipynb` locally reproduces the historic calculations on a small subset.
- `local/backup_checks/local_backup_check_bioclimatic_variable_calculation.ipynb` compares individual variables at a validation location.

These notebooks are checks only; they do not generate production inputs.

## Important calculations

The code calculates 14 variables: mean annual temperature (MAT), temperature seasonality (TS), mean temperature of the wettest/driest/warmest/coldest quarter, annual precipitation (AP), wettest/driest-month precipitation, precipitation seasonality (PS), and precipitation for wettest/driest/warmest/coldest quarters.

For quarter-based variables, the 12-month climatology is duplicated before three-month rolling windows are calculated. This allows quarters that cross the December--January boundary. 

## Inputs

| Location | Data | Dimensions | Producer/source | Used by |
| --- | --- | --- | --- | --- |
| `$AMAZON_DATA_DIR/intermediate/01_a_historical/T_AMAZON_base_period_historic.nc` | Historic `Tavg`, `Tmin`, `Tmax` monthly climatology, 1980--2014 | `(month, latitude, longitude)` | 01a | Historic driver |
| `$AMAZON_DATA_DIR/intermediate/01_a_historical/P_AMAZON_base_period_historic.nc` | Historic monthly precipitation climatology | `(month, latitude, longitude)` | 01a | Historic driver |
| `$AMAZON_DATA_DIR/intermediate/01_c_noresm2/<ssp>/tip/<deforestation>/T_monthly_ETresid_<period>.nc` | Future delta-corrected temperature | `(month, latitude, longitude)` | 01c | Future driver |
| `$AMAZON_DATA_DIR/intermediate/01_c_noresm2/<ssp>/tip/<deforestation>/P_monthly_ETresid_<period>.nc` | Future delta-corrected absolute precipitation | `(sample, month, latitude, longitude)` | 01c | Future driver |
| `$AMAZON_DATA_DIR/intermediate/01_c_noresm2/<ssp>/notip/T_monthly_ETresid_<period>.nc` and `P_monthly_ETresid_<period>.nc` | Future no-tipping temperature and absolute precipitation | `(month, latitude, longitude)` | 01c | Future driver |
| `local/data/` | Small historical validation inputs and reference outputs | Reduced spatial subset | Bundled | Local notebooks |

`<ssp>` is `ssp245` or `ssp370`; `<period>` is `2030_2044`, `2050_2069`, or `2080_2099`. The repository-local 01c precipitation validation file omits `sample` to remain small, so it is not a direct tipping-function input.

## Outputs

| Location | Data | Produced by | Downstream use |
| --- | --- | --- | --- |
| `$AMAZON_DATA_DIR/intermediate/02_bioclimatic_variables/bioclimatic_variables_historic_ERA5_1980_2014.nc` | Historic stack of 14 bioclimatic variables | Historic driver | 05, 06 |
| `$AMAZON_DATA_DIR/intermediate/02_bioclimatic_variables/<ssp>/tip/<deforestation>/bioclim_vars_ETresid_<period>.nc` | Future sampled bioclimatic-variable stack | Future driver | 05, 06 |
| `$AMAZON_DATA_DIR/intermediate/02_bioclimatic_variables/<ssp>/notip/bioclim_vars_ETresid_<period>.nc` | Future no-tipping bioclimatic-variable stack | Future driver | 05, 06 |
| `$AMAZON_OUTPUT_DIR/02_bioclimatic_variables/slurm/batch_scripts/` | Generated Slurm job scripts | Submission workflow | Cluster reproducibility |
| `$AMAZON_OUTPUT_DIR/02_bioclimatic_variables/slurm/stdout/` | Slurm standard-output logs | Cluster jobs | Diagnostics |
| `$AMAZON_OUTPUT_DIR/02_bioclimatic_variables/slurm/stderr/` | Slurm error logs | Cluster jobs | Diagnostics |
