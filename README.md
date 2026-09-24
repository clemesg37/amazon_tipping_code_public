# Amazon tipping amplifies biodiversity risk through teleconnected precipitation declines

Clemens Giesen<sup>1</sup>; Nico Wunderling<sup>1,2,3</sup>; Damaris Zurell<sup>4</sup>; Leonie Wenz<sup>1,5</sup>; Maximilian Kotz<sup>1,6,7,*</sup>

<sup>1</sup> Potsdam Institute for Climate Impact Research, Potsdam, Germany  
<sup>2</sup> Center for Critical Computational Studies (C3S), Goethe University Frankfurt, Germany  
<sup>3</sup> Senckenberg Research Institute and Natural History Museum, Frankfurt am Main, Germany  
<sup>4</sup> Institute for Biochemistry and Biology, University of Potsdam, Potsdam, Germany  
<sup>5</sup> Technische Universitaet Berlin, Berlin, Germany  
<sup>6</sup> Barcelona Supercomputing Centre, Barcelona, Spain  
<sup>7</sup> Centre for Biodiversity and Conservation Science, University of Queensland, Brisbane, Australia  
<sup>*</sup> Corresponding author


This repository contains the analysis and figure-generation code for the paper *Amazon tipping amplifies biodiversity risk through teleconnected precipitation declines*.

## Repository overview

The workflow prepares climate inputs, species ranges, bioclimatic predictors, species distribution models (SDMs), postprocessed datasets, and manuscript figures. It is organised into numbered folders that should be run in order:

| Folder | Purpose | Mostly run on |
| --- | --- | --- |
| `01_climate_data/` | Historical ERA5 processing, tipping-model precipitation data, and NorESM2 climate processing | HPC |
| `02_bioclimatic_variables/` | Historic and future bioclimatic-variable calculation | HPC; local notebooks for checks |
| `03_species_data/` | Species-range preparation and Amazon-overlap selection | HPC; local notebooks for checks |
| `04_rasterize_species/` | Range rasterization and species metadata creation | HPC |
| `05_variable_selection/` | Species-specific bioclimatic-variable selection | HPC |
| `06_SDM/` | Monte Carlo design, SDM fitting, evaluation, projection, and suitable-area summaries | HPC |
| `07_postprocess_data/` | Reusable climate, species-richness, deforestation, and SDM summary products | HPC and local preprocessing |
| `08_figures/` | Main-figure notebooks and selected HPC-based SI calculations | Local and HPC |

Every numbered workflow folder has its own README. These describe the folder's scope, scripts and their purposes, important calculations, detailed input/output tables, data locations, and any special provenance or execution notes.

## Two execution environments

### HPC code

The computationally intensive processing is run on an HPC: climate preprocessing, bioclimatic calculations, species-range operations, rasterization, SDM fitting and projection, and high-volume postprocessing. Cluster directories contain the calculation scripts together with generic Slurm templates or submit scripts.

Before running an HPC step, set the two environment variables described in [CONFIGURATION.md](CONFIGURATION.md):

```bash
export AMAZON_DATA_DIR=/path/to/amazon_data
export AMAZON_OUTPUT_DIR=/path/to/amazon_cluster_artifacts
```

`AMAZON_DATA_DIR` stores raw data and reusable derived data. `AMAZON_OUTPUT_DIR` stores generated batch scripts, standard output, standard error, and diagnostic plots. This keeps transient cluster artifacts outside the public code repository. Slurm templates use a neutral `account_name` placeholder where an account is required; replace it and add the site-specific module or environment activation commands required by the target HPC.

The full directory layout for both roots is defined in [CONFIGURATION.md](CONFIGURATION.md). Create the roots, export the variables, and use the documented subfolders. Scripts create their own output directories where appropriate.

### Local code

Local notebooks primarily create the manuscript figures and perform small validation or preprocessing tasks. They use repository-relative paths and locate the repository root automatically. Their compact input data are stored in `local/data/` folders or in a clearly documented local hand-off folder under step 07. No user-specific path editing should be necessary.

## Data handling and source data

The repository contains code, documentation, selected small local inputs, and data-layout instructions. Full raw data, full-resolution derived data, SDM model objects, and HPC artifacts are kept outside the repository under `AMAZON_DATA_DIR` and `AMAZON_OUTPUT_DIR`.

The main data sources include:

- ERA5 reanalysis climate data;
- IUCN species-range data and BirdLife/Birds of the World range data;
- NorESM2 climate simulations;
- precipitation-change output from the interacting tipping-model workflow;
- regridded Business-as-Usual Amazon deforestation-scenario inputs; and
- derived SDM outputs and area summaries produced by this workflow.

See the README in the relevant numbered folder for exact inputs, outputs, access requirements, and provenance. The regridded deforestation inputs are documented in `07_postprocess_data/local/deforestation_maps/DATA_SOURCE.md`. Large figure inputs, including the all-species area-change table, are distributed as companion data archives when they are too large for the code release; their destination and extraction instructions are documented beside the relevant local data folder.

## Getting started

1. Clone or download this repository.
2. Read [CONFIGURATION.md](CONFIGURATION.md) and create/configure `AMAZON_DATA_DIR` and `AMAZON_OUTPUT_DIR` if running the full HPC workflow.
3. Obtain and stage the required source data according to the relevant step READMEs.
4. Run the numbered HPC steps in order when reproducing the full analysis.
5. For figure-only reproduction, extract any companion large-data archives into their documented local folders, then run the notebook for the desired figure in `08_figures/`.

## Remaining tasks
- Create Conda environment specifications for the HPC and local workflows, including all package names and package versions.

## Configuration and folder-level documentation

[CONFIGURATION.md](CONFIGURATION.md) is the central reference for portable data and cluster-artifact paths. The numbered folder READMEs are the operational documentation for each pipeline step. Together, they specify what data a script needs, where it finds it, what it creates, and whether it is intended for the HPC or a local machine.
