DATA_ROOT <- Sys.getenv("AMAZON_DATA_DIR")
if (DATA_ROOT == "") {
  stop("Set AMAZON_DATA_DIR before running this script.")
}

library(terra)
library(dplyr)
library(stringr)

# ARGUMENTS
args <- commandArgs(trailingOnly = TRUE)

species_type <- args[1]
start_index  <- as.numeric(args[2])
end_index    <- as.numeric(args[3])

message("Species type: ", species_type)
message("MC range: ", start_index, " - ", end_index)

terraOptions(progress=1, memfrac=0.8)

# PATHS
base_path <- file.path(DATA_ROOT, "intermediate", "06_sdm", "models")

species_df <- read.csv(
file.path(DATA_ROOT, "intermediate", "04_rasterized_species", "full_species_list_amazon_updated.csv")
)

output_dir <- file.path(DATA_ROOT, "intermediate", "07_postprocess_data", "species_richness_from_SDM_projections", "results_by_species_taxa")
dir.create(output_dir, recursive=TRUE, showWarnings=FALSE)

# DETERMINE TAXON
taxon_type <- case_when(
  grepl("amphibian", species_type) ~ "amphibians",
  grepl("mammal", species_type) ~ "mammals",
  grepl("reptile", species_type) ~ "reptiles",
  grepl("bird", species_type) ~ "birds",
  TRUE ~ species_type
)

# DETERMINE SEASONALITY
bird_seasonality <- case_when(
  grepl("birds_resident", species_type) ~ "resident",
  grepl("birds_non_breeding", species_type) ~ "non_breeding",
  grepl("birds_breeding", species_type) ~ "breeding",
  TRUE ~ NA_character_
)

# SELECT SPECIES
if (taxon_type == "birds") {

  species_df <- species_df %>%
    filter(type == taxon_type,
           seasonality == bird_seasonality)

} else {

  species_df <- species_df %>%
    filter(type == taxon_type)

}

species_list <- species_df$Species

message("Number of species: ", length(species_list))

# MC SAMPLES
mc_samples <- read.csv(
file.path(DATA_ROOT, "intermediate", "06_sdm", "mc_samples", "MC_sample.csv")
)

mc_samples$mc_id <- 1:nrow(mc_samples)

# AMAZON MASK
amazon_rast <- rast(
file.path(DATA_ROOT, "intermediate", "01_c_noresm2", "amazon_mask", "amazon_mask.tif")
)

e <- ext(-90, -40, -30, 10)

amazon_crop <- crop(amazon_rast, e)

mask_rast_0 <- subst(amazon_crop, from=1, to=0)
mask_rast_0 <- classify(mask_rast_0, cbind(NA, NA))

# LOAD HISTORICAL PROJECTION
load_hist_tss <- function(species, algo, run){

  species_name <- gsub("_", ".", species)

  hist_dir <- file.path(
    base_path,
    species_name,
    "proj_my_species_projection_hist"
  )

  files <- list.files(hist_dir, pattern="TSSbin.tif$", full.names=TRUE)

  if(length(files)==0) return(NULL)

  r <- rast(files)

  layer_name <- grep(
    paste0("RUN", run, "_", algo, "$"),
    names(r),
    value=TRUE
  )

  if(length(layer_name)==0) return(NULL)

  r[[layer_name]]
}

# AMAZON MASK FUNCTION
mask_to_amazon <- function(r){

  rc <- crop(r, e)
  re <- extend(rc, mask_rast_0)
  rm <- mask(re, mask_rast_0)

  cover(rm, mask_rast_0)
}

# MAIN LOOP
for(mc_i in start_index:end_index){

  message("Processing MC sample ", mc_i)

  algo <- mc_samples$algo[mc_i]
  run  <- mc_samples$model_run[mc_i]

  r_list <- list()

  for(sp in species_list){

    r <- tryCatch(
      load_hist_tss(sp, algo, run),
      error=function(e) NULL
    )

    if(!is.null(r)){
      r_list[[length(r_list)+1]] <- mask_to_amazon(r)
    }

  }

  if(length(r_list)==0) next

  r_stack <- rast(r_list)

  richness <- sum(r_stack)

  writeRaster(
    richness,
    file.path(
      output_dir,
      paste0("historic_richness_", species_type, "_MC_", mc_i, ".tif")
    ),
    overwrite=TRUE
  )

}