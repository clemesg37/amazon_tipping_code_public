DATA_ROOT <- Sys.getenv("AMAZON_DATA_DIR")
if (DATA_ROOT == "") {
  stop("Set AMAZON_DATA_DIR before running this script.")
}

library(terra)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4) {
  stop(
    "Usage: calculate_mean_richness_cluster.R ",
    "<ssp> <tip> <deforestation> <period>"
  )
}

ssp <- args[1]
tip <- args[2]
deforestation <- args[3]
time_period <- args[4]

scenario_dir <- file.path(
  DATA_ROOT, "intermediate", "07_postprocess_data",
  "species_richness_from_SDM_projections", "results_ETresid",
  paste0(ssp, "_", tip, "_", deforestation), time_period
)
output_dir <- file.path(
  DATA_ROOT, "intermediate", "07_postprocess_data",
  "species_richness_from_SDM_projections", "results_mean_ETresid",
  paste0(ssp, "_", tip, "_", deforestation), time_period
)

if (!dir.exists(scenario_dir)) {
  stop("All-species MC richness directory does not exist: ", scenario_dir)
}
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

mc_file <- function(kind, mc_id) {
  file.path(
    scenario_dir,
    paste0(kind, "_species_richness_MC_all_species_", mc_id, ".tif")
  )
}

for (kind in c("historic", "future", "delta")) {
  files <- vapply(seq_len(100), function(mc_id) mc_file(kind, mc_id), character(1))
  missing <- files[!file.exists(files)]

  if (length(missing) > 0) {
    stop(
      "Cannot summarise ", kind, " richness: ",
      length(missing), " of 100 all-species MC files are missing.\n",
      paste(missing, collapse = "\n")
    )
  }

  mc_stack <- terra::rast(files)
  mean_map <- terra::mean(mc_stack, na.rm = TRUE)
  sd_map <- terra::app(mc_stack, fun = stats::sd, na.rm = TRUE)

  terra::writeRaster(
    mean_map,
    file.path(output_dir, paste0(kind, "_species_richness_mean_all_species.tif")),
    overwrite = TRUE
  )
  terra::writeRaster(
    sd_map,
    file.path(output_dir, paste0(kind, "_species_richness_sd_all_species.tif")),
    overwrite = TRUE
  )

  message("Saved mean and SD maps for ", kind, " richness.")
}