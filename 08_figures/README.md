# 08 Figures

This folder contains the local plotting notebooks for the paper's main figures. It does not run the large SDM, climate, or raster calculations. Those calculations are performed in earlier steps, usually on the HPC, and their compact plotting inputs are copied into the documented local-data folders before a figure notebook is run.

## Main figures

| Figure | Notebook | Where it runs | Main local inputs | Output |
| --- | --- | --- | --- | --- |
| Figure 1 | `main_figures/figure_1/plot_fig_1_local.ipynb` | Local | Combined global species-richness raster, precipitation time series, precipitation-change maps, and binary deforestation maps in `main_figures/figure_1/local/data/` | `main_figures/figure_1/output/final_figure_1.png` |
| Figure 2 | `main_figures/figure_2/plot_fig_2_local.ipynb` | Local | Mean SDM-projection species-richness rasters copied from `07_postprocess_data/local/species_richness_from_SDM_projections/data/results_mean_ETresid/` | `main_figures/figure_2/output/` |
| Figure 3 | `main_figures/figure_3/plot_fig_3_local.ipynb` | Local | Large SDM area-change table from `07_postprocess_data/local/sdm_area_change/` and the small species metadata table from step 04 | `main_figures/figure_3/output/final_figure_3.png` |
| Figure 4 | `main_figures/figure_4/plot_fig_4_local.ipynb` | Local | Mean SR rasters from the Figure 2 data folder and the 2050-2069 binary deforestation map in the Figure 1 data folder | `main_figures/figure_4/output/final_figure_4.png` |

Each notebook locates the repository root automatically, so no personal local or HPC path must be edited. The output directories are created when the notebooks run.

## Input hand-off from step 07

Step 07 creates reusable postprocessed data. Only the data needed to reproduce a figure locally are copied into this repository's local data folders:

- Figure 1 receives its compact climate, deforestation, and global SR products in `main_figures/figure_1/local/data/`.
- Figure 2 reads the copied `results_mean_ETresid/` tree retained under `07_postprocess_data/local/species_richness_from_SDM_projections/data/`.
- Figure 3 reads `final_amazon_area_ETresid_updated.csv` from `07_postprocess_data/local/sdm_area_change/`. This large CSV is distributed through the accompanying data ZIP; see that folder's README for extraction instructions.
- Figure 4 reuses the Figure 1 deforestation map and Figure 2 SR inputs.

## Appendix figures

Appendix-figure code will be added later. It should follow the same convention: put reusable cluster-derived inputs in a documented local data folder, use repository-relative paths in the local plotting notebook, and write rendered figures to a figure-specific `output/` directory.

## Software

The plotting notebooks use a local Python environment with packages such as `numpy`, `pandas`, `xarray`, `rioxarray`, `rasterio`, `matplotlib`, `seaborn`, `geopandas`, `geodatasets`, and `cartopy`, depending on the figure. Exact environment/version documentation remains a project-level release task.
