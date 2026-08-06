# 05 -- Select bioclimatic variables for species-level SDMs

## Folder overview

This folder defines a species-specific calibration area and extracts the historical and future bioclimatic variables required by the SDM workflow. The same selected grid cells are used for the historical stack and every future scenario for a given species. Folder 06 uses these outputs for SDM training and projection.

## Scripts

- `cluster/select_bioclimatic_vars_for_species.R`: selects a calibration area for a batch of species and writes masked historic and future bioclimatic stacks.
- `cluster/submit_select_bioclim_vars.py`: creates and submits Slurm jobs for one deliberately selected taxon/size-class subgroup at a time.
- `cluster/slurm_template.sh`: generic Slurm template; account, partition, and R-module commands are site-specific placeholders.

There is no local validation notebook or bundled calculation input for this high-volume step.

## Important calculations

For each species, the script reads its binary presence raster from 04, samples up to 50 occupied cell centres, and creates a spherical-distance buffer. The initial buffer radius is calibrated against the square root of rasterized area: it starts at 300 km for the smallest species and is calibrated against an area of 1,000,000 km2. The radius grows by 20 percent until the selected land cells contain more than 11 times the full number of presence cells, or until the half-circumference safety limit is reached.

The selected cells are then used to crop and mask the historic stack and every future scenario, ensuring comparable calibration and projection domains.

## Inputs

| Location | Data | Producer/source | Used by |
| --- | --- | --- | --- |
| `$AMAZON_DATA_DIR/intermediate/04_rasterized_species/full_species_list_amazon_updated.csv` | Species taxon, bird seasonality, presence-cell count, rasterized area, and size class | 04 | Species and buffer selection |
| `$AMAZON_DATA_DIR/intermediate/04_rasterized_species/{amphibians,mammals,reptiles}/Selected_species_raster_path_*.rds` | Non-bird species-to-raster lookup tables | 04 | Presence-raster lookup |
| `$AMAZON_DATA_DIR/intermediate/04_rasterized_species/birds/{resident,breeding,non_breeding}/Selected_species_raster_path_birds_*.rds` | Bird species-to-raster lookup tables | 04 | Presence-raster lookup |
| `$AMAZON_DATA_DIR/intermediate/02_bioclimatic_variables/bioclimatic_variables_historic_ERA5_1980_2014.nc` | Historic stack of 14 bioclimatic variables | 02 | Historic extraction |
| `$AMAZON_DATA_DIR/intermediate/02_bioclimatic_variables/<ssp>/notip/bioclim_vars_ETresid_<period>.nc` | Future no-tipping stack | 02 | Future extraction |
| `$AMAZON_DATA_DIR/intermediate/02_bioclimatic_variables/<ssp>/tip/<deforestation>/bioclim_vars_ETresid_<period>.nc` | Future tipping stack | 02 | Future extraction |

`<ssp>` is `ssp245` or `ssp370`; `<deforestation>` is `no_deforestation` or `deforestation`; `<period>` is `2030_2044`, `2050_2069`, or `2080_2099`.

## Outputs

| Location | Data | Produced by | Downstream use |
| --- | --- | --- | --- |
| `$AMAZON_DATA_DIR/intermediate/05_selected_bioclimatic_variables/data/<species>_historic.tif` | Historic variables masked to the calibration area | Selection script | 06 SDM training |
| `$AMAZON_DATA_DIR/intermediate/05_selected_bioclimatic_variables/data/<species>_<ssp>_<tip>_<deforestation>_<period>.tif` | Future variables masked to the same area | Selection script | 06 SDM projections |
| `$AMAZON_OUTPUT_DIR/05_selected_bioclimatic_variables/slurm/{batch_scripts,stdout,stderr}/` | Generated Slurm scripts and job logs | Submission workflow | Cluster reproducibility |

No diagnostic plots are created in this step.

## Submission configuration

The launcher is intentionally configured for one manageable subgroup at a time. Set `SPECIES_TYPE` and `CLASS_VALUE` in `submit_select_bioclim_vars.py`; its `SPECIES_COUNTS` dictionary documents all configured taxon/class counts. Jobs process 50 species each by default.

## Execution order

1. Complete 04, including raster lookup tables and `full_species_list_amazon_updated.csv`.
2. Complete 02 for all required scenarios and periods.
3. Set `AMAZON_DATA_DIR` and `AMAZON_OUTPUT_DIR` as described in [CONFIGURATION.md](../CONFIGURATION.md).
4. Choose a subgroup in `submit_select_bioclim_vars.py` and submit it on the HPC.

