DATA_ROOT <- Sys.getenv("AMAZON_DATA_DIR")
if (DATA_ROOT == "") {
  stop("Set AMAZON_DATA_DIR before running this script.")
}

library(terra)
library(stringr)
library(dplyr)
library(purrr)


# Arguments
args <- commandArgs(trailingOnly = TRUE)

start_index <- as.numeric(args[1])
end_index   <- as.numeric(args[2])
ssp         <- args[3]
tip         <- args[4]
deforestation <- args[5]
time_period <- args[6]
species_type <- args[7]

# path 
base_path <- file.path(DATA_ROOT, "intermediate", "06_sdm", "models")
species_df <- read.csv(file.path(DATA_ROOT, "intermediate", "04_rasterized_species", "full_species_list_amazon_updated.csv"))

# Determine type 
taxon_type <- case_when(
  grepl("amphibian", species_type) ~ "amphibians",
  grepl("mammal", species_type) ~ "mammals",
  grepl("reptile", species_type) ~ "reptiles",
  grepl("bird", species_type) ~ "birds",
  TRUE ~ species_type
)

# Determine seasonality (ONLY relevant for birds)
bird_seasonality <- case_when(
  grepl("birds_resident", species_type) ~ "resident",
  grepl("birds_non_breeding", species_type) ~ "non_breeding",
  grepl("birds_breeding", species_type) ~ "breeding",
  TRUE ~ NA_character_
)

# Select species
if (taxon_type == "birds") {
  species_df <- species_df %>%
    filter(
      type == taxon_type,
      seasonality == bird_seasonality
    )
} else {
  species_df <- species_df %>%
    filter(
      type == taxon_type
    )
}

all_species <- species_df$Species


# LOAD MC SAMPLE DEFINITIONS 
mc_samples <- read.csv(file.path(DATA_ROOT, "intermediate", "06_sdm", "mc_samples", "MC_sample.csv"))

# Guarantee correct ordering (1..100)
mc_samples <- mc_samples %>% mutate(mc_id = row_number())

# AMAZON MASK PREPARATION
amazon_rast <- rast(file.path(DATA_ROOT, "intermediate", "01_c_noresm2", "amazon_mask", "amazon_mask.tif"))

e <- ext(-90, -40, -30, 10)
amazon_crop <- crop(amazon_rast, e)

mask_rast_0 <- subst(amazon_crop, from = 1, to = 0)
mask_rast_0 <- classify(mask_rast_0, cbind(NA, NA))

# FUNCTIONS

# Load historical projection (matching algo + run)
load_hist_tss <- function(species, algo, run) {
  species_name <- gsub("_", ".", species)
  hist_dir <- file.path(base_path, species_name, "proj_my_species_projection_hist")
  
  r <- rast(list.files(hist_dir, pattern = "TSSbin.tif$", full.names = TRUE))
  layer_name <- grep(paste0("RUN", run, "_", algo, "$"), names(r), value = TRUE)
  
  return(r[[layer_name]])
}

# Load future projection for specific MC sample (algo, run, prec_sample)
load_future_tss_notip <- function(species, algo, run) {
  species_name <- gsub("_", ".", species)
  
  pattern <- paste0(
    "proj_", species, "_",
    ssp, "_", tip, "_", deforestation, "_", time_period)
  
  
  dirs <- list.dirs(file.path(base_path, species_name), recursive = FALSE, full.names = TRUE)
  
  match_dir <- dirs[str_detect(basename(dirs), pattern)]
  
  if (length(match_dir) != 1) {
    stop(paste("Projection folder not found:", species, pattern))
  }
  
  f <- list.files(match_dir, pattern = "TSSbin.tif$", full.names = TRUE)
  f_rast <- rast(f)
  layer_name <- grep(paste0("RUN", run, "_", algo, "$"), names(f_rast), value = TRUE)
  
  # Select 
  return(f_rast[[layer_name]])
}


# Load future projection for specific MC sample (algo, run, prec_sample)
load_future_tss <- function(species, algo, run, prec_sample) {
  species_name <- gsub("_", ".", species)
  
  pattern <- paste0(
    "proj_", species, "_",
    ssp, "_", tip, "_", deforestation, "_", time_period,
    "_", algo, "_", run, "_", prec_sample, "$"
  )
  
  dirs <- list.dirs(file.path(base_path, species_name), recursive = FALSE, full.names = TRUE)
  
  match_dir <- dirs[str_detect(basename(dirs), pattern)]
  
  if (length(match_dir) != 1) {
    stop(paste("Projection folder not found:", species, pattern))
  }
  
  f <- list.files(match_dir, pattern = "TSSbin.tif$", full.names = TRUE)
  return(rast(f))
}

mask_to_amazon <- function(r) {
  rc <- crop(r, e)
  re <- extend(rc, mask_rast_0)
  rm <- mask(re, mask_rast_0)
  out <- cover(rm, mask_rast_0)
  return(out)
}

# OUTPUT PATHS
output_dir_base <- file.path(DATA_ROOT, "intermediate", "07_postprocess_data", "species_richness_from_SDM_projections", "results_ETresid")
output_dir <- file.path(output_dir_base, paste0(ssp, "_", tip, "_", deforestation), time_period)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)


# MAIN LOOP
if (tip == "notip") {
  for (mc_i in start_index:end_index) {
    
    message("Processing MC sample ", mc_i)
    
    hist_richness  <- mask_rast_0
    future_richness <- mask_rast_0
    
    # Load MC sample 
    ms <- mc_samples %>% filter(mc_id == mc_i)
    algo <- ms$algo
    run  <- ms$model_run
    
    for (sp in all_species) {
      tryCatch({
        
        
        hist_r <- load_hist_tss(sp, algo, run)
        fut_r  <- load_future_tss_notip(sp, algo, run)
        
        hist_richness  <- hist_richness + mask_to_amazon(hist_r)
        future_richness <- future_richness + mask_to_amazon(fut_r)
        
      }, error=function(e) print(paste("error:", sp, e)))
    }
    
    delta <- future_richness - hist_richness
    
    writeRaster(hist_richness,  file.path(output_dir, paste0("historic_species_richness_MC_", species_type, mc_i, ".tif")), overwrite=TRUE)
    writeRaster(future_richness,file.path(output_dir, paste0("future_species_richness_MC_", species_type, mc_i, ".tif")), overwrite=TRUE)
    writeRaster(delta,          file.path(output_dir, paste0("delta_species_richness_MC_", species_type, mc_i, ".tif")), overwrite=TRUE)
  }
  
} else {
  
  for (mc_i in start_index:end_index) {
    
    message("Processing MC sample ", mc_i)
    
    hist_richness  <- mask_rast_0
    future_richness <- mask_rast_0
    
    ms <- mc_samples %>% filter(mc_id == mc_i)
    algo <- ms$algo
    run  <- ms$model_run
    prec <- ms$prec_sample
    
    for (sp in all_species) {
      tryCatch({
        
        hist_r <- load_hist_tss(sp, algo, run)
        fut_r  <- load_future_tss(sp, algo, run, prec)
        
        hist_richness  <- hist_richness + mask_to_amazon(hist_r)
        future_richness <- future_richness + mask_to_amazon(fut_r)
        
      }, error=function(e) print(paste("error:", sp, e)))
    }
    
    delta <- future_richness - hist_richness
    
    writeRaster(hist_richness,  file.path(output_dir, paste0("historic_species_richness_MC_", species_type, mc_i, ".tif")), overwrite=TRUE)
    writeRaster(future_richness,file.path(output_dir, paste0("future_species_richness_MC_", species_type, mc_i, ".tif")), overwrite=TRUE)
    writeRaster(delta,          file.path(output_dir, paste0("delta_species_richness_MC_", species_type, mc_i, ".tif")), overwrite=TRUE)
  }
  
}

