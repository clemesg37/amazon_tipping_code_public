# 04 -- Rasterize selected species ranges

## Folder overview

This folder converts the Amazon-selected species polygons from folder 03 into binary presence rasters on the 0.5-degree ERA5 grid. It then creates species-to-raster lookup tables and a combined species table with raster-cell counts, rasterized area, taxonomic group, bird seasonality, and size class. These outputs are used by the variable-selection and SDM steps.

## Scripts

### Production code

- `cluster/rasterize_species.R` rasterizes one GPKG part for one taxon or bird-seasonality group.
- `cluster/submit_rasterize_jobs.py` creates and submits one Slurm job per input part for the explicitly selected species group(s); its part-count dictionary documents all seven groups.
- `cluster/slurm_template.sh` is the generic Slurm template used by the submission script; account, partition, and R-module commands are site-specific placeholders.
- `cluster/create_species_raster_path.R` creates one named RDS lookup table of raster paths for each group after all rasterization jobs finish.
- `cluster/create_full_species_list_with_classes.R` combines the lookup tables, counts occupied raster cells, calculates rasterized area, and assigns size classes.

### Local reference data

`local/data/full_species_list_amazon_updated.csv` is a bundled reference copy of the final species table for inspection. It is not used as a production input and does not replace the full raster outputs.

## Important calculations

For each species, `terra::rasterize(..., cover = TRUE)` estimates the fraction of each 0.5-degree grid cell covered by the selected polygon. A cell is retained as a presence cell only when coverage is greater than 0.5; species with fewer than 50 retained cells are not written. The final table calculates the area of retained cells in km² and assigns classes from the number of presence cells.

| Presence cells | Class |
| --- | --- |
| 50–150 | `supersmall` |
| 151–400 | `small` |
| 401–1,000 | `medium` |
| 1,001–2,500 | `large` |
| ≥ 2,501 | `superlarge` |

## Inputs

| Location | Data | Producer/source | Used by |
| --- | --- | --- | --- |
| `$AMAZON_DATA_DIR/intermediate/03_species_data/{amphibians,mammals,reptiles_part1,reptiles_part2}/species_for_modelling/filtered_species_<part>.gpkg` | Amazon-selected non-bird range polygons | 03 | `rasterize_species.R` |
| `$AMAZON_DATA_DIR/intermediate/03_species_data/birds/{resident,breeding,non_breeding}/species_for_modelling/filtered_species_<part>.gpkg` | Amazon-selected bird range polygons by seasonality | 03 | `rasterize_species.R` |
| `$AMAZON_DATA_DIR/intermediate/01_a_historical/T_AMAZON_base_period_historic.nc` | Historical ERA5 grid and CRS, used as rasterization template | 01a | `rasterize_species.R` |

The expected part counts are 50 amphibian, 28 mammal, 24 reptile-part-1, 23 reptile-part-2, 50 resident-bird, 15 breeding-bird, and 15 non-breeding-bird files.

## Outputs

| Location | Data | Produced by | Downstream use |
| --- | --- | --- | --- |
| `$AMAZON_DATA_DIR/intermediate/04_rasterized_species/{amphibians,mammals,reptiles}/*.tif` | Binary non-bird presence rasters | `rasterize_species.R` | 05, 06 |
| `$AMAZON_DATA_DIR/intermediate/04_rasterized_species/birds/{resident,breeding,non_breeding}/*.tif` | Binary bird presence rasters by seasonality | `rasterize_species.R` | 05, 06 |
| `$AMAZON_DATA_DIR/intermediate/04_rasterized_species/**/Selected_species_raster_path_*.rds` | Named species-to-raster-path lookup tables | `create_species_raster_path.R` | 05, 06 |
| `$AMAZON_DATA_DIR/intermediate/04_rasterized_species/full_species_list_amazon_updated.csv` | Species metadata, presence-cell count, rasterized area, and size class | `create_full_species_list_with_classes.R` | 06 |
| `$AMAZON_OUTPUT_DIR/04_rasterized_species/slurm/{batch_scripts,stdout,stderr}/` | Generated Slurm scripts and job logs | Submission workflow | Cluster reproducibility |

No diagnostic plots are created in this step.

## Execution order

1. Set `SELECTED_SPECIES_TYPES` in `submit_rasterize_jobs.py` to the group(s) to run, then execute it on the HPC after setting `AMAZON_DATA_DIR` and `AMAZON_OUTPUT_DIR` as described in [CONFIGURATION.md](../CONFIGURATION.md).
2. After all rasterization jobs finish, run `create_species_raster_path.R`.
3. Run `create_full_species_list_with_classes.R` to create the table used downstream.

