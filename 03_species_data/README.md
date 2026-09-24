# 03 -- Species-distribution data preparation

## Folder overview

This folder prepares bird and non-bird distribution polygons for species-distribution modelling. It filters source ranges, divides large datasets into job-sized files, and selects species with more than 30% of their range in the Amazon Basin.

## Scripts

- `cluster/non_birds_species/cut_and_select_non_bird_species_dataset.py`: filters IUCN amphibian, mammal, and reptile ranges and splits them into GPKG parts.
- `cluster/non_birds_species/select_non_bird_species_in_amazon_region.py`: calculates Amazon overlap and writes selected non-bird ranges.
- `cluster/non_birds_species/select_amphibian_species_subset.py`: creates the small amphibian subset used for validation.
- `cluster/birds/cut_and_select_bird_species_dataset.py`: filters BirdLife/BOTW ranges and splits them by seasonality.
- `cluster/birds/select_bird_species_in_amazon_region.py`: calculates Amazon overlap for birds.
- `cluster/*/submit_files_*.py`: generates and submits Slurm jobs.
- `cluster/*/slurm_species_data.sh`: generic Slurm templates.

## Important calculations

Source polygons are restricted to extant/possibly extant/probably extant, native or reintroduced ranges and to the Americas. Non-bird and bird polygons are simplified and merged by species, intersected with the Amazon mask, and retained where Amazon overlap exceeds 30%. Birds retain resident, breeding, and non-breeding seasonality.

## Inputs

| Location | Data | Producer/source | Used by |
| --- | --- | --- | --- |
| `$AMAZON_DATA_DIR/raw/03_species_ranges/iucn/` | IUCN non-bird shapefiles | External/licensed source | Non-bird preparation |
| `$AMAZON_DATA_DIR/raw/03_species_ranges/birds/BOTW_2024_2.gpkg` | Raw BirdLife/BOTW ranges | External/licensed source; manually staged to `intermediate/03_species_data/birds/` before processing | Bird-data staging |
| `$AMAZON_DATA_DIR/intermediate/03_species_data/birds/BOTW_2024_2.gpkg` | Staged BirdLife/BOTW ranges | Manual staging from the external/licensed raw source | Bird preparation |
| `$AMAZON_DATA_DIR/intermediate/01_c_noresm2/amazon_mask/amazon_mask.tif` | Amazon Basin mask | 01c | Amazon-overlap selection |

## Outputs

| Location | Data | Produced by | Used by |
| --- | --- | --- | --- |
| `$AMAZON_DATA_DIR/intermediate/03_species_data/<taxon>/*.gpkg` | Filtered, job-sized source-range parts | Cut/select scripts | Amazon-overlap scripts |
| `$AMAZON_DATA_DIR/intermediate/03_species_data/<taxon>/species_for_modelling/` | Amazon-selected species ranges | Selection scripts | 04 |
| `$AMAZON_DATA_DIR/intermediate/03_species_data/amphibians/subset/` | Small validation subset | Amphibian subset script | Local validation |
| `$AMAZON_OUTPUT_DIR/03_species_data/slurm/` | Batch scripts, standard output, and error logs | Submission workflow | Cluster reproducibility |

## Local validation

`local/` contains small bird and amphibian files plus notebooks that validate filtering and Amazon-overlap steps. These files are checks only and are not relevant for further calculations.