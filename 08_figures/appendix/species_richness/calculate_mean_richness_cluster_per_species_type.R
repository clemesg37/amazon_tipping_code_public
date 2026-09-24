# Mean taxon-specific species richness across the 100 matched MC samples.

DATA_ROOT <- Sys.getenv("AMAZON_DATA_DIR")
if (DATA_ROOT == "") {
  stop("Set AMAZON_DATA_DIR to the project data directory before running this script.")
}

library(terra)

args <- commandArgs(trailingOnly = TRUE)

species_type <- args[[1]]
valid_taxa <- c("amphibians", "mammals", "reptiles", "birds_resident")

SSPS <- c("ssp245", "ssp370")
TIPS <- c("tip", "notip")
DEFORESTATIONS <- c("deforestation", "no_deforestation")
TIME_PERIODS <- c("2030_2044", "2050_2069", "2080_2099")
MAP_KINDS <- c("historic", "future", "delta")
MC_IDS <- seq_len(100)

input_root <- file.path(
  DATA_ROOT, "intermediate", "07_postprocess_data",
  "species_richness_from_SDM_projections", "results_ETresid"
)
output_root <- file.path(
  DATA_ROOT, "intermediate", "07_postprocess_data",
  "species_richness_from_SDM_projections", "results_by_species_taxa"
)

mc_file <- function(directory, map_kind, taxon, mc_id) {
  file.path(
    directory,
    paste0(map_kind, "_species_richness_MC_", taxon, mc_id, ".tif")
  )
}

for (ssp in SSPS) {
  for (tip in TIPS) {
    deforestation_values <- if (tip == "tip") DEFORESTATIONS else "no_deforestation"

    for (deforestation in deforestation_values) {
      for (time_period in TIME_PERIODS) {
        scenario_name <- paste(ssp, tip, deforestation, time_period, sep = "_")
        input_dir <- file.path(input_root, paste0(ssp, "_", tip, "_", deforestation), time_period)
        output_dir <- file.path(output_root, paste0(ssp, "_", tip, "_", deforestation), time_period)

        if (!dir.exists(input_dir)) {
          stop("Input directory does not exist for ", scenario_name, ": ", input_dir)
        }
        dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

        for (map_kind in MAP_KINDS) {
          files <- vapply(
            MC_IDS,
            function(mc_id) mc_file(input_dir, map_kind, species_type, mc_id),
            character(1)
          )
          missing_files <- files[!file.exists(files)]

          if (length(missing_files) > 0) {
            stop(
              "Cannot calculate ", map_kind, " mean for ", species_type,
              " in ", scenario_name, ": ", length(missing_files),
              " of 100 MC maps are missing.\nFirst missing files:\n",
              paste(head(missing_files, 10), collapse = "\n")
            )
          }

          message(
            "Calculating mean ", map_kind, " richness for ", species_type,
            " (", scenario_name, ") from 100 MC maps."
          )
          mean_map <- terra::mean(terra::rast(files), na.rm = TRUE)

          output_file <- file.path(
            output_dir,
            paste0(map_kind, "_species_richness_mean_", species_type, ".tif")
          )
          terra::writeRaster(mean_map, output_file, overwrite = TRUE)
          message("Saved: ", output_file)
        }
      }
    }
  }
}

