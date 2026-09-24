# 08 Figures

This folder contains the code used to create the manuscript's main and Supporting Information (SI) figures. It does not rerun the large climate, SDM, or species-richness calculations. Those products are generated in steps 01-07, normally on the HPC, and only the compact data required for local calculation are copied into the documented data folders.

All local notebooks find the repository root automatically. They therefore use repository-relative paths and do not require personal paths to be edited. Output folders are created when a notebook runs.


## Main figures

| Figure | Notebook | Where it runs | Main inputs | Output |
| --- | --- | --- | --- | --- |
| Figure 1 | `main_figures/figure_1/plot_fig_1_local.ipynb` | Local | Global species-richness raster, precipitation time series and maps, and binary deforestation maps in `main_figures/figure_1/local/data/` | `main_figures/figure_1/output/final_figure_1.png` |
| Figure 2 | `main_figures/figure_2/plot_fig_2_local.ipynb` | Local | Mean total species-richness maps in `07_postprocess_data/local/species_richness_from_SDM_projections/data/results_mean_ETresid/` | `main_figures/figure_2/output/` |
| Figure 3 | `main_figures/figure_3/plot_fig_3_local.ipynb` | Local | `07_postprocess_data/local/sdm_area_change/final_amazon_area_ETresid_updated.csv` and the step-04 species metadata | `main_figures/figure_3/output/final_figure_3.png` |
| Figure 4 | `main_figures/figure_4/plot_fig_4_local.ipynb` | Local | Figure-2 mean richness maps and the 2050--2069 binary deforestation map from the Figure-1 data folder | `main_figures/figure_4/output/final_figure_4.png` |

### Data hand-off from step 07

Only products needed to reproduce a plot locally are retained in this repository:

- Figure 1 receives its compact climate, deforestation, and global species-richness products in `main_figures/figure_1/local/data/`.
- Figure 2 reads the copied `results_mean_ETresid/` tree under `07_postprocess_data/local/species_richness_from_SDM_projections/data/`.
- Figure 3 reads the large area-change CSV from `07_postprocess_data/local/sdm_area_change/`. This file is distributed through the accompanying data archive; see that folder's README for extraction instructions.
- Figure 4 reuses the Figure-1 deforestation map and Figure-2 richness inputs.

## Supporting Information figures

| Topic | Code | Where it runs | Inputs and outputs |
| --- | --- | --- | --- |
| Bioclimatic variables | `appendix/bioclimatic_variables/plot_bioclims_for_SI.ipynb` | HPC or another environment with the staged step-01/02 data | Reads `AMAZON_DATA_DIR` and writes plots below `AMAZON_OUTPUT_DIR/08_figures/appendix/bioclimatic_variables/plots/`. |
| Calibration and validation TSS | `appendix/tss_scores/tss_random_blockCV_plots.ipynb` | HPC or another environment with the step-04 and step-06 data | Reads model outputs from `AMAZON_DATA_DIR/intermediate/06_sdm/models/`, writes cached CSVs and figures below `AMAZON_OUTPUT_DIR/08_figures/appendix/tss_scores/`. |
| Area-change violin plots | `appendix/area_change/violin_plots_by_region.ipynb` | Local | Uses the local area-change data and writes figures to `appendix/area_change/plots/`. |
| Species richness by taxon and range-size class | `appendix/species_richness/SR_per_taxa_per_size.ipynb` | Local | Reads copied mean maps from `appendix/species_richness/data_from_cluster/` and writes `sr_by_taxa.png` and `sr_by_range_size_class.png` to `appendix/species_richness/plots/`. |
| Alternative precipitation ensemble | `appendix/figure_1_ETresid_ETsimul/plot_ETresid_ETsimul_local.ipynb` | Local | Reads `period_means_ETresid_ETsimul.nc` and `precipitation_time_series_ETresid_ETsimul.csv` from its `local/data/` folder, reuses the Figure-1 deforestation maps, and writes to `appendix/figure_1_ETresid_ETsimul/plots/`. |

### Range-size-class richness calculations

`appendix/species_richness/` also contains the path-neutral HPC code used to derive the SI richness maps by species range-size class. It uses the final SDM outputs and the 100-row production Monte Carlo (MC) table from steps 04 and 06.

1. Set `AMAZON_DATA_DIR`, `AMAZON_OUTPUT_DIR`, and the site-specific `AMAZON_HPC_MODULES` environment variables.
2. Run `submit_batch_jobs_range_class_richness.py`. It calls `calculate_SR_by_range_class.R` for every range-size class, valid scenario-period combination, and MC sample. The resulting historical, future, and change maps are written below `AMAZON_DATA_DIR/intermediate/07_postprocess_data/species_richness_from_SDM_projections/results_by_range_size_class/`.
3. After all 100 MC maps are present, run `submit_batch_jobs_mean_SR_per_range_class.py`. It calls `mean_SR_per_range_size_class.R` and creates the corresponding mean maps.

`calculate_mean_richness_cluster_per_species_type.R` is the analogous mean-map step for taxonomic groups. It expects the taxon-specific MC maps produced by step 07 and writes the means below `results_by_species_taxa/`. The compact mean-map products used by `SR_per_taxa_per_size.ipynb` are copied into `data_from_cluster/` for local plotting.



