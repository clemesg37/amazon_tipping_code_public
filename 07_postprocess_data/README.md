# 07 Postprocess data

This folder creates reusable datasets after the SDM and climate-processing steps. It separates high-volume cluster products from the small Figure 1 input bundle copied to `08_figures/main_figures/figure_1/local/data/` for local plotting.
## Components

| Location | Script or resource | Purpose |
| --- | --- | --- |
| `cluster/sdm_area_change/` | `create_full_dataset_area_change.py` and `submit_full_dataset.py` | Concatenates one `area_all_MC_models.csv` file per species from step 06 and calculates four relative area-change measures. |
| `cluster/species_richness_from_SDM_projections/` | `calculate_richness_cluster_final.R`, `calculate_total_richness_per_mc.R`, and `calculate_mean_richness_cluster.R` | Creates taxon-level historical, future, and delta richness rasters for each MC sample; aggregates matching MC IDs across all taxa; then calculates all-species MC means and SDs. |
| `cluster/species_richness_from_SDM_projections/` | `calculate_SR_by_taxa.R`, `calculate_SR_by_range_class.R`, and `mean_SR_per_range_size_class.R` | Creates historical SR rasters grouped by taxon or range-size class, plus class means. |
| `local/species_richness_from_SDM_projections/` | `data/results_mean_ETresid/` | Local copy location for the mean SR GeoTIFFs used by plotting notebooks. |
| `cluster/figure_1/climate_timeseries/` | `figure_1_plot_time_series_ET.py` and `submit_climate_timeseries.py` | Applies the precipitation-change ensemble to the historical ERA5 precipitation climatology, calculates annual climate-only and tipping time series, and writes period-mean precipitation-change maps. It also creates a diagnostic plot. |
| `cluster/figure_1/species_richness/` | `plot_global_SR_parallel.R` | Rasterizes IUCN ranges for one selected non-bird taxonomic group and sums one occupied/not-occupied layer per species to create a 0.5 degree species-richness raster. |
| `cluster/figure_1/species_richness/` | `plot_global_SR_birds_parallel.R` | Performs the equivalent calculation for the selected BirdLife seasonal category; the current setting is resident birds. |
| `cluster/figure_1/species_richness/` | `combine_global_SR.R` | Sums amphibians, mammals, reptile parts 1 and 2, and resident birds into `SR_world_all_taxa_land_05deg.tif`. |
| `local/deforestation_maps/` | `prepare_deforestation_maps.ipynb` | Reads the included regridded BaU source data, interpolates it to the ERA5 grid, applies the documented 0.5 threshold, and creates the three binary deforestation maps used in Figure 1. |
| `local/deforestation_maps/regridded_deforestation_scenarios/` | coauthor-provided input data | Versioned regridded BaU data. See `DATA_SOURCE.md` for release status and provenance. |

## Important calculations

The SDM area-change table is intentionally large because it retains results across species, scenarios, periods, dispersal assumptions, and Monte Carlo model outputs. It is a reusable intermediate dataset, not a Figure 1 input. Keep it outside the code repository under the data root; archive or distribute a compressed copy alongside compact summary datasets when needed.

The climate script applies the same delta approach documented in `01_climate_data/01_b_tipping_model_pr_data/README.md`: the bias-corrected precipitation-change fields `PC_CC` and `PC_CCTIP` are converted from percent to fractions and applied to the ERA5 baseline precipitation as `baseline * (1 + delta)`. See the step 01 documentation for the generation and interpretation of these change fields.

The Figure 1 richness scripts first create one raster per taxonomic input. `combine_global_SR.R` then creates `SR_world_all_taxa_land_05deg.tif` by summing the five required rasters. Copy this compact combined raster to the Figure 1 local data bundle after the cluster run.

For SDM-projection richness, the workflow preserves the joint Monte Carlo structure: it first creates taxon-level historic, future, and delta maps for each MC ID; then sums the four matching taxon maps into all-species maps for that same MC ID. Finally, it calculates the mean and SD across the 100 all-species MC maps. Each scenario-period therefore produces six all-species GeoTIFFs: historic, future, and delta richness, each as a mean and SD map.

## Inputs and outputs

| Input | Location | Used by | Output |
| --- | --- | --- | --- |
| Per-species SDM area summaries | `$AMAZON_DATA_DIR/intermediate/06_sdm/models/<species>/area_results/area_all_MC_models.csv` | `create_full_dataset_area_change.py` | `$AMAZON_DATA_DIR/intermediate/07_postprocess_data/sdm_area_change/final_amazon_area_ETresid_updated.csv` |
| SDM projection rasters, MC design, species metadata, and Amazon mask | `$AMAZON_DATA_DIR/intermediate/06_sdm/models/`, `06_sdm/mc_samples/MC_sample.csv`, `04_rasterize_species/full_species_list_amazon_updated.csv`, and `01_c_noresm2/amazon_mask/amazon_mask.tif` | SDM-projection SR scripts | `species_richness_from_SDM_projections/results_ETresid/`, `results_mean_ETresid/`, `results_by_species_taxa/`, and `results_by_class/` |
| Historical ERA5 precipitation and temperature | `$AMAZON_DATA_DIR/intermediate/01_a_historical/` | climate script; local deforestation notebook | ERA5-grid climate and deforestation Figure 1 inputs |
| Precipitation-change ensemble | `$AMAZON_DATA_DIR/intermediate/01_b_precipitation_changes/amazon_precip_ETresid_perc_changes_ssp_ssp245_tipscenario_tipping_climate_change_deforestation_MC.nc` | climate script; local deforestation notebook | `precipitation_time_series_residET.csv`, `period_means.nc` |
| IUCN range files | `$AMAZON_DATA_DIR/raw/03_species_ranges/iucn/` | non-bird richness script | `SR_<group>_05deg.tif` |
| BirdLife range GeoPackage | `$AMAZON_DATA_DIR/raw/03_species_ranges/birds/BOTW_2024_2.gpkg` | bird richness script | `SR_birds_resident_05deg.tif` with the current setting |
| Five taxon richness rasters | `$AMAZON_DATA_DIR/intermediate/07_postprocess_data/figure_1/species_richness/` | `combine_global_SR.R` | `SR_world_all_taxa_land_05deg.tif` |
| Coauthor-provided regridded BaU data | `local/deforestation_maps/regridded_deforestation_scenarios/` | local deforestation notebook | `binary_defors_map_2030_2044.nc`, `binary_defors_map_2050_2069.nc`, `binary_defors_map_2080_2099.nc` |

Cluster outputs are stored under `$AMAZON_OUTPUT_DIR/07_postprocess_data/...`, including `slurm/batch_scripts/`, `slurm/stdout/`, `slurm/stderr/`, and diagnostic plots. Reusable data products are stored under `$AMAZON_DATA_DIR/intermediate/07_postprocess_data/...`.

## Running on a cluster

Set `AMAZON_DATA_DIR` and `AMAZON_OUTPUT_DIR` as described in `CONFIGURATION.md`. The generic Slurm files are templates: add only site-specific module or environment activation commands. `submit_climate_timeseries.py` and `submit_full_dataset.py` create run-specific Slurm scripts in the external artifact root. `submit_scripts_worldSR.py` deliberately submits only the groups listed in `SELECTED_SPECIES_TYPES`, so that species-richness jobs can be submitted in manageable batches. `slurm_worldSR.sh` runs the bird richness script separately.

## Figure 1 hand-off

Copy these compact products to `08_figures/main_figures/figure_1/local/data/` before running the local Figure 1 notebook:

- `precipitation_time_series_residET.csv`
- `period_means.nc`
- the three `binary_defors_map_*.nc` files
- `SR_world_all_taxa_land_05deg.tif` (the combined richness raster)

For later figures that use SDM-projection species richness, copy the complete `results_mean_ETresid/` directory into `07_postprocess_data/local/species_richness_from_SDM_projections/data/`; it is not a Figure 1 input.

The notebook and final plot paths in step 08 are intentionally handled there, rather than here.
