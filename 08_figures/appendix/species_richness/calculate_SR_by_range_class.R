# Species richness per range-size class and matched MC sample.
# Usage:
# Rscript --vanilla calculate_SR_by_range_class.R \
#   <start_index> <end_index> <ssp> <tip> <deforestation> <period> <range_class>

DATA_ROOT <- Sys.getenv("AMAZON_DATA_DIR")
if (DATA_ROOT == "") {
  stop("Set AMAZON_DATA_DIR to the project data directory before running this script.")
}

library(terra)
library(dplyr)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 7) {
  stop(
    "Usage: calculate_SR_by_range_class.R ",
    "<start_index> <end_index> <ssp> <tip> <deforestation> <period> <range_class>"
  )
}

start_index <- as.integer(args[[1]])
end_index <- as.integer(args[[2]])
ssp <- args[[3]]
tip <- args[[4]]
deforestation <- args[[5]]
time_period <- args[[6]]
target_class <- args[[7]]

if (is.na(start_index) || is.na(end_index) || start_index < 1 || end_index < start_index) {
  stop("MC indices must be positive integers with start_index <= end_index.")
}

valid_classes <- c("supersmall", "small", "medium", "large", "superlarge")
if (!(target_class %in% valid_classes)) {
  stop("Unknown range-size class: ", target_class, ". Expected one of: ",
       paste(valid_classes, collapse = ", "))
}
if (!(tip %in% c("tip", "notip"))) {
  stop("tip must be either 'tip' or 'notip'.")
}
if (tip == "notip" && deforestation != "no_deforestation") {
  stop("The notip scenario must use deforestation = 'no_deforestation'.")
}

terraOptions(progress = 1, memfrac = 0.8)

models_root <- file.path(DATA_ROOT, "intermediate", "06_sdm", "models")
species_file <- file.path(
  DATA_ROOT, "intermediate", "04_rasterize_species",
  "full_species_list_amazon_updated.csv"
)
mc_file_path <- file.path(
  DATA_ROOT, "intermediate", "06_sdm", "mc_samples", "MC_sample.csv"
)
amazon_mask_path <- file.path(
  DATA_ROOT, "intermediate", "01_c_noresm2", "amazon_mask", "amazon_mask.tif"
)

required_files <- c(species_file, mc_file_path, amazon_mask_path)
missing_required <- required_files[!file.exists(required_files)]
if (length(missing_required) > 0) {
  stop("Missing required input file(s):\n", paste(missing_required, collapse = "\n"))
}
if (!dir.exists(models_root)) {
  stop("SDM models directory does not exist: ", models_root)
}

species_df <- read.csv(species_file)
class_species <- species_df |>
  dplyr::filter(
    class == target_class,
    type != "birds" | seasonality == "resident"
  ) |>
  dplyr::distinct(Species, .keep_all = TRUE)

if (nrow(class_species) == 0) {
  stop("No modelled species found for range-size class: ", target_class)
}
if (anyDuplicated(class_species$Species)) {
  stop("Species selection contains duplicate species names for class: ", target_class)
}
all_species <- class_species$Species
message("Selected ", length(all_species), " modelled species in class ", target_class)

mc_samples <- read.csv(mc_file_path)
if (nrow(mc_samples) != 100) {
  stop("Expected exactly 100 rows in MC_sample.csv; found ", nrow(mc_samples))
}
required_mc_columns <- c("algo", "model_run", "prec_sample")
missing_mc_columns <- setdiff(required_mc_columns, names(mc_samples))
if (length(missing_mc_columns) > 0) {
  stop("MC_sample.csv is missing column(s): ", paste(missing_mc_columns, collapse = ", "))
}
mc_samples$mc_id <- seq_len(nrow(mc_samples))
if (end_index > nrow(mc_samples)) {
  stop("Requested MC index ", end_index, " but only ", nrow(mc_samples), " MC samples exist.")
}

amazon_rast <- terra::rast(amazon_mask_path)
amazon_extent <- terra::ext(-90, -40, -30, 10)
amazon_crop <- terra::crop(amazon_rast, amazon_extent)
mask_rast_0 <- terra::subst(amazon_crop, from = 1, to = 0)
mask_rast_0 <- terra::classify(mask_rast_0, cbind(NA, NA))

load_hist_tss <- function(species, algo, run) {
  species_name <- gsub("_", ".", species)
  hist_dir <- file.path(models_root, species_name, "proj_my_species_projection_hist")
  tss_file <- list.files(hist_dir, pattern = "TSSbin\\.tif$", full.names = TRUE)

  if (length(tss_file) != 1) {
    stop("Expected one historic TSS binary raster for ", species, "; found ", length(tss_file))
  }

  projection <- terra::rast(tss_file)
  layer_name <- grep(paste0("RUN", run, "_", algo, "$"), names(projection), value = TRUE)
  if (length(layer_name) != 1) {
    stop(
      "Expected one historic layer for ", species, ", ", algo, ", run ", run,
      "; found ", length(layer_name)
    )
  }
  projection[[layer_name]]
}

load_future_tss_notip <- function(species, algo, run) {
  species_name <- gsub("_", ".", species)
  pattern <- paste0(
    "proj_", species, "_", ssp, "_", tip, "_", deforestation, "_", time_period, "$"
  )
  dirs <- list.dirs(file.path(models_root, species_name), recursive = FALSE, full.names = TRUE)
  match_dir <- dirs[grepl(pattern, basename(dirs))]

  if (length(match_dir) != 1) {
    stop("Expected one non-tipping projection folder for ", species, "; found ", length(match_dir))
  }

  tss_file <- list.files(match_dir, pattern = "TSSbin\\.tif$", full.names = TRUE)
  if (length(tss_file) != 1) {
    stop("Expected one non-tipping TSS binary raster for ", species, "; found ", length(tss_file))
  }

  projection <- terra::rast(tss_file)
  layer_name <- grep(paste0("RUN", run, "_", algo, "$"), names(projection), value = TRUE)
  if (length(layer_name) != 1) {
    stop(
      "Expected one non-tipping layer for ", species, ", ", algo, ", run ", run,
      "; found ", length(layer_name)
    )
  }
  projection[[layer_name]]
}

load_future_tss_tip <- function(species, algo, run, prec_sample) {
  species_name <- gsub("_", ".", species)
  pattern <- paste0(
    "proj_", species, "_", ssp, "_", tip, "_", deforestation, "_", time_period,
    "_", algo, "_", run, "_", prec_sample, "$"
  )
  dirs <- list.dirs(file.path(models_root, species_name), recursive = FALSE, full.names = TRUE)
  match_dir <- dirs[grepl(pattern, basename(dirs))]

  if (length(match_dir) != 1) {
    stop("Expected one tipping projection folder for ", species, "; found ", length(match_dir))
  }

  tss_file <- list.files(match_dir, pattern = "TSSbin\\.tif$", full.names = TRUE)
  if (length(tss_file) != 1) {
    stop("Expected one tipping TSS binary raster for ", species, "; found ", length(tss_file))
  }
  terra::rast(tss_file)
}

mask_to_amazon <- function(raster) {
  cropped <- terra::crop(raster, amazon_extent)
  extended <- terra::extend(cropped, mask_rast_0)
  masked <- terra::mask(extended, mask_rast_0)
  terra::cover(masked, mask_rast_0)
}

output_dir <- file.path(
  DATA_ROOT, "intermediate", "07_postprocess_data",
  "species_richness_from_SDM_projections", "results_by_range_size_class",
  paste0(ssp, "_", tip, "_", deforestation), time_period
)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

for (mc_i in start_index:end_index) {
  message("Processing class ", target_class, ", MC sample ", mc_i)

  sample_row <- mc_samples[mc_samples$mc_id == mc_i, , drop = FALSE]
  algo <- sample_row$algo
  run <- sample_row$model_run
  prec_sample <- sample_row$prec_sample

  historic_richness <- mask_rast_0
  future_richness <- mask_rast_0
  failures <- character()

  for (species in all_species) {
    result <- tryCatch({
      historic <- load_hist_tss(species, algo, run)
      future <- if (tip == "notip") {
        load_future_tss_notip(species, algo, run)
      } else {
        load_future_tss_tip(species, algo, run, prec_sample)
      }
      list(historic = mask_to_amazon(historic), future = mask_to_amazon(future))
    }, error = function(error) {
      failures <<- c(failures, paste0(species, ": ", conditionMessage(error)))
      NULL
    })

    if (!is.null(result)) {
      historic_richness <- historic_richness + result$historic
      future_richness <- future_richness + result$future
    }
  }

  if (length(failures) > 0) {
    stop(
      "No output was written for class ", target_class, ", MC ", mc_i,
      " because ", length(failures), " species failed:\n",
      paste(failures, collapse = "\n")
    )
  }

  delta_richness <- future_richness - historic_richness
  terra::writeRaster(historic_richness, file.path(output_dir, paste0("historic_species_richness_MC_", target_class, mc_i, ".tif")), overwrite = TRUE)
  terra::writeRaster(future_richness, file.path(output_dir, paste0("future_species_richness_MC_", target_class, mc_i, ".tif")), overwrite = TRUE)
  terra::writeRaster(delta_richness, file.path(output_dir, paste0("delta_species_richness_MC_", target_class, mc_i, ".tif")), overwrite = TRUE)
}



