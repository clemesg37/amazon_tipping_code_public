# Mean species richness per range-size class across the 100 matched MC samples.
# Usage: Rscript --vanilla mean_SR_per_range_size_class.R <range_class>

DATA_ROOT <- Sys.getenv("AMAZON_DATA_DIR")
if (DATA_ROOT == "") {
  stop("Set AMAZON_DATA_DIR to the project data directory before running this script.")
}

library(terra)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) {
  stop(
    "Usage: mean_SR_per_range_size_class.R ",
    "<supersmall|small|medium|large|superlarge>"
  )
}

target_class <- args[[1]]
valid_classes <- c("supersmall", "small", "medium", "large", "superlarge")
if (!(target_class %in% valid_classes)) {
  stop("Unknown range-size class: ", target_class, ". Expected one of: ",
       paste(valid_classes, collapse = ", "))
}

SSPS <- c("ssp245", "ssp370")
TIPS <- c("tip", "notip")
DEFORESTATIONS <- c("deforestation", "no_deforestation")
TIME_PERIODS <- c("2030_2044", "2050_2069", "2080_2099")
MAP_KINDS <- c("historic", "future", "delta")
MC_IDS <- seq_len(100)

results_root <- file.path(
  DATA_ROOT, "intermediate", "07_postprocess_data",
  "species_richness_from_SDM_projections", "results_by_range_size_class"
)

mc_file <- function(directory, map_kind, range_class, mc_id) {
  file.path(
    directory,
    paste0(map_kind, "_species_richness_MC_", range_class, mc_id, ".tif")
  )
}

for (ssp in SSPS) {
  for (tip in TIPS) {
    deforestation_values <- if (tip == "tip") DEFORESTATIONS else "no_deforestation"

    for (deforestation in deforestation_values) {
      for (time_period in TIME_PERIODS) {
        scenario_name <- paste(ssp, tip, deforestation, time_period, sep = "_")
        scenario_dir <- file.path(
          results_root,
          paste0(ssp, "_", tip, "_", deforestation),
          time_period
        )

        if (!dir.exists(scenario_dir)) {
          stop("MC richness directory does not exist for ", scenario_name, ": ", scenario_dir)
        }

        for (map_kind in MAP_KINDS) {
          files <- vapply(
            MC_IDS,
            function(mc_id) mc_file(scenario_dir, map_kind, target_class, mc_id),
            character(1)
          )
          missing_files <- files[!file.exists(files)]

          if (length(missing_files) > 0) {
            stop(
              "Cannot calculate ", map_kind, " mean for class ", target_class,
              " in ", scenario_name, ": ", length(missing_files),
              " of 100 MC maps are missing.\nFirst missing files:\n",
              paste(head(missing_files, 20), collapse = "\n")
            )
          }

          message(
            "Calculating mean ", map_kind, " richness for class ", target_class,
            " (", scenario_name, ") from 100 MC maps."
          )
          mean_map <- terra::mean(terra::rast(files), na.rm = TRUE)
          output_file <- file.path(
            scenario_dir,
            paste0(map_kind, "_species_richness_mean_", target_class, ".tif")
          )
          terra::writeRaster(mean_map, output_file, overwrite = TRUE)
          message("Saved: ", output_file)
        }
      }
    }
  }
}

