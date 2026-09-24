# Data, cluster artifacts, and output locations

This repository contains code and selected small local plotting inputs. Full raw data, full-resolution derived data, SDM model objects, and HPC artifacts must be kept outside the repository.

Set these environment variables before running a path-neutral HPC script or notebook:

```bash
export AMAZON_DATA_DIR=/path/to/amazon_data
export AMAZON_OUTPUT_DIR=/path/to/amazon_cluster_artifacts
```

On Windows PowerShell:

```powershell
$env:AMAZON_DATA_DIR = 'D:\amazon_data'
$env:AMAZON_OUTPUT_DIR = 'D:\amazon_cluster_artifacts'
```

## Data root

Keep source datasets under `raw/`. Keep every derived dataset that is reused by a later workflow step under `intermediate/`.

```text
$AMAZON_DATA_DIR/
  raw/
    01_a_era5/
    01_b_tipping_model/
    01_c_noresm2/
    03_species_ranges/
  intermediate/
    01_a_historical/
    01_b_precipitation_changes/
    01_c_noresm2/
    02_bioclimatic_variables/
    03_species_data/
    04_rasterize_species/
      full_species_list_amazon_updated.csv
      rasterized_species/
    05_selected_bioclimatic_variables/
    06_sdm/
      models/
      mc_samples/
    07_postprocess_data/
      sdm_area_change/
      figure_1/
        climate_timeseries/
        species_richness/
        deforestation_maps/
      species_richness_from_SDM_projections/
        results_ETresid/
        results_mean_ETresid/
        results_by_species_taxa/
        results_by_range_size_class/
    08_figures/
      appendix/
        figure_1_ETresid_ETsimul/
          plot_data/
```

The small `08_figures/.../plot_data/` directory contains cluster-derived inputs for the local alternative-precipitation SI plot. Main and SI figure images themselves are written repository-relatively below `08_figures/`, rather than to `AMAZON_DATA_DIR`.

## Cluster-artifact root

`AMAZON_OUTPUT_DIR` contains transient or diagnostic products: generated Slurm batch files, standard output, standard error, cached plot tables, and diagnostic plots. It is intentionally separate from reusable data products in `AMAZON_DATA_DIR`.

```text
$AMAZON_OUTPUT_DIR/
  01_a_historical/
    slurm/{batch_scripts,stdout,stderr}/
    plots/
  01_b_tipping_model_pr_data/
    slurm/{batch_scripts,stdout,stderr}/
    plots/
  01_c_NorESM2/
    slurm/{batch_scripts,stdout,stderr}/
    plots/
  02_bioclimatic_variables/
    slurm/{batch_scripts,stdout,stderr}/
  03_species_data/
    slurm/{batch_scripts,stdout,stderr}/
  04_rasterize_species/
    slurm/{batch_scripts,stdout,stderr}/
  05_selected_bioclimatic_variables/
    slurm/{batch_scripts,stdout,stderr}/
  06_sdm/
    slurm/{batch_scripts,stdout,stderr}/
  07_postprocess_data/
    sdm_area_change/slurm/{batch_scripts,stdout,stderr}/
    figure_1/climate_timeseries/slurm/{batch_scripts,stdout,stderr}/
    figure_1/climate_timeseries/plots/
    figure_1/species_richness/slurm/{batch_scripts,stdout,stderr}/
    species_richness_from_SDM_projections/{batch_scripts,stdout,stderr}/
  08_figures/
    appendix/
      bioclimatic_variables/plots/
      tss_scores/{data,plots}/
      species_richness/
        range_class_mc/slurm/{batch_scripts,stdout,stderr}/
        range_class_mean/slurm/{batch_scripts,stdout,stderr}/
```

## Local plotting inputs

Some products are intentionally copied from the data root into repository-local folders so a figure can be rendered without a full HPC data installation:

- `08_figures/main_figures/figure_1/local/data/` holds the compact Figure 1 climate, deforestation, and global richness inputs.
- `07_postprocess_data/local/species_richness_from_SDM_projections/data/` holds the mean total-richness maps used by Figures 2 and 4.
- `07_postprocess_data/local/sdm_area_change/` documents the companion area-change CSV used by Figure 3. 
- `08_figures/appendix/*/local/data/` and `08_figures/appendix/species_richness/data_from_cluster/` hold compact SI plotting inputs.


