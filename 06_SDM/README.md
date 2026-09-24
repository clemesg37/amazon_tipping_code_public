# 06 -- Species distribution models

## Folder overview

This folder creates the Monte Carlo design and trains, evaluates, and projects species distribution models (SDMs). It uses the species-specific bioclimatic rasters from 05, species presence rasters from 04, and the Amazon mask from 01c. One output directory is created directly per species (with no taxon or seasonality subfolders), containing tuning summaries, final-model evaluation, variable importance, BIOMOD projection artifacts, and area summaries.

## Scripts

- `cluster/MC_samples/create_MC_samples.R`: creates 100 random combinations of algorithm, final-model run, and precipitation sample for tipping-scenario projections.
- `cluster/run_and_evaluate_SDMs/cluster_tuning_HP_blockCV_projection_MCapproach_ETresid.R`: runs the complete per-species SDM workflow.
- `cluster/run_and_evaluate_SDMs/submit_hp_tuning_blockCV.py`: creates and submits Slurm jobs for a deliberately selected taxon and index range.
- `cluster/run_and_evaluate_SDMs/slurm_template.sh`: generic Slurm template; account, partition, and R-module commands are site-specific placeholders.

`local/data/MC_sample.csv` is a small local reference copy of the MC design. It is not used by the production workflow.

## Important calculations

For each species, the workflow loads its historic calibration raster and removes highly correlated predictors using VIF-based `corSelect` with a correlation threshold of 0.8. It creates pseudo-absences at ten times the number of presences and uses five spatial block-CV folds for hyperparameter tuning.

Four algorithms are tuned and trained: GLM, GAM, RFd, and GBM. Final models use ten train/validation runs. For tipping scenarios, the 100-row MC design selects an algorithm, model run, and precipitation sample for each projection. No-tipping scenarios project all final models deterministically. The code calculates suitable area under no dispersal and full dispersal, both globally and within the Amazon mask.

For birds, this workflow models only the resident-bird group (`birds_resident`). Breeding and non-breeding BirdLife groups are retained in the broader species-data preparation tables, but are intentionally excluded from 06. All modelled species therefore use one flat per-species output layout: `models/<species>/`.


## Inputs

| Location | Data | Producer/source | Used by |
| --- | --- | --- | --- |
| `$AMAZON_DATA_DIR/intermediate/04_rasterized_species/full_species_list_amazon_updated.csv` | Species metadata, presence-cell count, rasterized area, and class | 04 | Select species for a job |
| `$AMAZON_DATA_DIR/intermediate/04_rasterized_species/**/Selected_species_raster_path_*.rds` | Species-to-presence-raster lookup tables | 04 | Presence rasters |
| `$AMAZON_DATA_DIR/intermediate/05_selected_bioclimatic_variables/data/<species>_historic.tif` | Historic species-specific bioclimatic stack | 05 | SDM calibration and training |
| `$AMAZON_DATA_DIR/intermediate/05_selected_bioclimatic_variables/data/<species>_<ssp>_<tip>_<deforestation>_<period>.tif` | Future species-specific bioclimatic stacks | 05 | Projections |
| `$AMAZON_DATA_DIR/intermediate/01_c_noresm2/amazon_mask/amazon_mask.tif` | Amazon mask | 01c | Amazon-specific suitable area |
| `$AMAZON_DATA_DIR/intermediate/06_sdm/mc_samples/MC_sample.csv` | 100-row MC projection design | `create_MC_samples.R` | Tipping projections |

## Outputs

| Location | Data | Produced by | Downstream use |
| --- | --- | --- | --- |
| `$AMAZON_DATA_DIR/intermediate/06_sdm/mc_samples/MC_sample.csv` | Monte Carlo design | MC-sample script | Tipping projections |
| `$AMAZON_DATA_DIR/intermediate/06_sdm/models/<species>/models_evaluation_blockCV_tuning/{GLM,GAM,RFd,GBM}/*_summary_tuning.csv` | Spatial-CV tuning results | SDM workflow | Model selection and audit |
| `$AMAZON_DATA_DIR/intermediate/06_sdm/models/<species>/set_tuned_HP/final_HP_TSS_overview.csv` | Selected hyperparameters and tuning TSS | SDM workflow | Final training |
| `$AMAZON_DATA_DIR/intermediate/06_sdm/models/<species>/final_model_evaluation/final_model_tuned.csv` | Final-model evaluation | SDM workflow | Results interpretation |
| `$AMAZON_DATA_DIR/intermediate/06_sdm/models/<species>/variable_importance/variable_importance_final_model.csv` | Variable importance | SDM workflow | Results interpretation |
| `$AMAZON_DATA_DIR/intermediate/06_sdm/models/<species>/area_results/area_all_MC_models.csv` | Historic and future suitable area under dispersal assumptions | SDM workflow | 07 summary statistics |
| `$AMAZON_OUTPUT_DIR/06_sdm/slurm/{batch_scripts,stdout,stderr}/` | Generated Slurm scripts and job logs | Submission workflow | Cluster reproducibility |

## Execution order

1. Complete 04 and 05 for the species to model.
2. Run `create_MC_samples.R` once to create the MC design.
3. Set `AMAZON_DATA_DIR` and `AMAZON_OUTPUT_DIR` as described in [CONFIGURATION.md](../CONFIGURATION.md).
4. Set `SPECIES_TYPE`, `START_INDEX`, and `END_INDEX` in `submit_hp_tuning_blockCV.py` to a manageable subgroup, then submit on the HPC.

## Software

The SDM workflow uses `terra`, `sf`, `fuzzySim`, `biomod2`, `sp`, `stringr`, `s2`, `ggplot2`, `blockCV`, and `dplyr`. The submission script requires Python and Slurm (`sbatch`).
