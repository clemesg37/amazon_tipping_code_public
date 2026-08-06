DATA_ROOT <- Sys.getenv("AMAZON_DATA_DIR")
if (DATA_ROOT == "") {
  stop("Set AMAZON_DATA_DIR before running this script.")
}


library(terra)
library(stringr)
library(dplyr)
library(purrr)

species_type <- "mammals"
ssps <- c("ssp245","ssp370")
tips <- c("tip", "notip") 
deforestations <- c("deforestation", "no_deforestation")
time_periods <- c("2030_2044", "2050_2069", "2080_2099")

for (ssp in ssps) {
  for (tip in tips) {
    defor_values <- if (tip == "tip") deforestations else "no_deforestation"
    for (deforestation in defor_values) {
      for (time_period in time_periods) {
        
        load_maps_dir_base <- file.path(DATA_ROOT, "intermediate", "07_postprocess_data", "species_richness_from_SDM_projections", "results_ETresid")
        output_dir_base <- file.path(DATA_ROOT, "intermediate", "07_postprocess_data", "species_richness_from_SDM_projections", "results_mean_ETresid")
        load_maps_dir <- file.path(load_maps_dir_base, paste0(ssp, "_", tip, "_", deforestation), time_period)
        output_dir <- file.path(output_dir_base, paste0(ssp, "_", tip, "_", deforestation), time_period)
        
        if (!dir.exists(output_dir)) {
          dir.create(output_dir, recursive = TRUE)
        }

        if (tip == "notip") {
          message("Calculating mean richness for notip scenario...")
          
          # read all calculated mc files
          hist_files   <- list.files(load_maps_dir, pattern = paste0("^historic_species_richness_MC_", species_type, ".*\\.tif$"), full.names = TRUE)
          future_files <- list.files(load_maps_dir, pattern = paste0("^future_species_richness_MC_", species_type, ".*\\.tif$"), full.names = TRUE)
          delta_files  <- list.files(load_maps_dir, pattern = paste0("^delta_species_richness_MC_", species_type, ".*\\.tif$"), full.names = TRUE)
          
          #hist_richness <- rast(file.path(load_maps_dir, "historic_species_richness.tif"))
          #future_richness <- rast(file.path(load_maps_dir, "future_species_richness.tif"))
          #delta_richness <- rast(file.path(load_maps_dir, "delta_species_richness.tif"))
          
          # stack 
          hist_stack   <- rast(hist_files)
          future_stack <- rast(future_files)
          delta_stack  <- rast(delta_files)
          
          # mean over all samples
          hist_richness_mean   <- mean(hist_stack, na.rm = TRUE)
          future_richness_mean <- mean(future_stack, na.rm = TRUE)
          delta_richness_mean  <- mean(delta_stack, na.rm = TRUE)
          
          # save
          writeRaster(hist_richness_mean, 
                      file.path(output_dir, paste0("historic_species_richness_mean_", species_type, ".tif")), 
                      overwrite = TRUE)
          writeRaster(future_richness_mean, 
                      file.path(output_dir, paste0("future_species_richness_mean_", species_type, ".tif")), 
                      overwrite = TRUE)
          writeRaster(delta_richness_mean, 
                      file.path(output_dir, paste0("delta_species_richness_mean_", species_type, ".tif")), 
                      overwrite = TRUE)
          
        } else {
          message("Calculating mean richness across all MC samples...")
          
          # read all calculated mc files
          hist_files   <- list.files(load_maps_dir, pattern = paste0("^historic_species_richness_MC_", species_type, ".*\\.tif$"), full.names = TRUE)
          future_files <- list.files(load_maps_dir, pattern = paste0("^future_species_richness_MC_", species_type, ".*\\.tif$"), full.names = TRUE)
          delta_files  <- list.files(load_maps_dir, pattern = paste0("^delta_species_richness_MC_", species_type, ".*\\.tif$"), full.names = TRUE)
          
          # stack 
          hist_stack   <- rast(hist_files)
          future_stack <- rast(future_files)
          delta_stack  <- rast(delta_files)
          
          # mean over all samples
          hist_richness_mean   <- mean(hist_stack, na.rm = TRUE)
          future_richness_mean <- mean(future_stack, na.rm = TRUE)
          delta_richness_mean  <- mean(delta_stack, na.rm = TRUE)
          
          # save
          writeRaster(hist_richness_mean, 
                      file.path(output_dir, paste0("historic_species_richness_mean_", species_type, ".tif")), 
                      overwrite = TRUE)
          writeRaster(future_richness_mean, 
                      file.path(output_dir, paste0("future_species_richness_mean_", species_type, ".tif")), 
                      overwrite = TRUE)
          writeRaster(delta_richness_mean, 
                      file.path(output_dir, paste0("delta_species_richness_mean_", species_type, ".tif")), 
                      overwrite = TRUE)
        }
      }
    }
  }
}



