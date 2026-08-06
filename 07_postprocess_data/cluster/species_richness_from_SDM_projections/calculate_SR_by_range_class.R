DATA_ROOT <- Sys.getenv("AMAZON_DATA_DIR")
if (DATA_ROOT == "") {
  stop("Set AMAZON_DATA_DIR before running this script.")
}

library(terra)
library(dplyr)
library(stringr)

# ARGUMENTS
args <- commandArgs(trailingOnly = TRUE)

target_class <- args[1]
start_index  <- as.numeric(args[2])
end_index    <- as.numeric(args[3])


# PATHS
base_path <- file.path(DATA_ROOT, "intermediate", "06_sdm", "models")

species_df <- read.csv(
file.path(DATA_ROOT, "intermediate", "04_rasterized_species", "full_species_list_amazon_updated.csv")
)

output_dir <- file.path(DATA_ROOT, "intermediate", "07_postprocess_data", "species_richness_from_SDM_projections", "results_by_class")

dir.create(output_dir, recursive=TRUE, showWarnings=FALSE)

terraOptions(progress=1, memfrac=0.8)

# SELECT SPECIES OF THIS CLASS
species_class <- species_df %>%
  filter(class == target_class) %>%
  pull(Species)


# LOAD MC SAMPLES
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

# FUNCTION: LOAD HISTORICAL TSS
load_hist_tss <- function(species, algo, run){

  species_name <- gsub("_", ".", species)

  hist_dir <- file.path(
    base_path,
    species_name,
    "proj_my_species_projection_hist"
  )

  files <- list.files(hist_dir,
                      pattern="TSSbin.tif$",
                      full.names=TRUE)

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

# FUNCTION: MASK TO AMAZON
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

  for(sp in species_class){

    r <- tryCatch(
      load_hist_tss(sp, algo, run),
      error=function(e) NULL
    )

    if(!is.null(r)){
      r_list[[length(r_list)+1]] <- mask_to_amazon(r)
    }

  }

  if(length(r_list)==0){
    message("No rasters found for MC ", mc_i)
    next
  }

  # STACK RASTERS
  r_stack <- rast(r_list)

  # FAST SUM
  richness <- sum(r_stack)

  # WRITE RESULT
  writeRaster(
    richness,
    file.path(
      output_dir,
      paste0("historic_richness_", target_class, "_MC_", mc_i, ".tif")
    ),
    overwrite=TRUE
  )

}