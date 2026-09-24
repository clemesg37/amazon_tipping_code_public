# Data, cluster artifacts, and output locations

This repository contains code and small validation subsets only. Full raw data, derived full-resolution data, model objects, and cluster artifacts must be kept outside the repository.

Set these environment variables before running the pipeline:

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

Keep every derived dataset that serves as input to a later pipeline step under `intermediate/`. Only source datasets belong under `raw/`.

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
      rasterized_species/
    05_selected_bioclimatic_variables/
    06_sdm/
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
```

Final summary tables and figures will be defined later; they should live in a separate final-results location, not in `intermediate/`.

## Cluster-artifact root

Every step with cluster code receives its own folder for generated Slurm scripts, standard output, error output, and diagnostic plots:

```text
$AMAZON_OUTPUT_DIR/
  01_a_historical/
    slurm/batch_scripts/
    slurm/stdout/
    slurm/stderr/
    plots/
  01_b_tipping_model_pr_data/
    slurm/batch_scripts/
    slurm/stdout/
    slurm/stderr/
    plots/
  01_c_NorESM2/
    slurm/batch_scripts/
    slurm/stdout/
    slurm/stderr/
    plots/
  02_bioclimatic_variables/
    slurm/batch_scripts/
    slurm/stdout/
    slurm/stderr/
    plots/
  07_postprocess_data/
    sdm_area_change/slurm/{batch_scripts,stdout,stderr}/
    figure_1/climate_timeseries/slurm/{batch_scripts,stdout,stderr}/
    figure_1/climate_timeseries/plots/
    figure_1/species_richness/slurm/{batch_scripts,stdout,stderr}/
  # Repeat the same structure for every later step with cluster code.
```

Slurm templates are versioned in each step’s `cluster/` directory.