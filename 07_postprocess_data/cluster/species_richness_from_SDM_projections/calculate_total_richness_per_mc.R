DATA_ROOT <- Sys.getenv("AMAZON_DATA_DIR")
if (DATA_ROOT == "") {
  stop("Set AMAZON_DATA_DIR before running this script.")
}

library(terra)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 6) {
  stop(
    "Usage: calculate_total_richness_per_mc.R ",
    "<start_index> <end_index> <ssp> <tip> <deforestation> <period>"
  )
}

start_index <- as.integer(args[1])
end_index <- as.integer(args[2])
ssp <- args[3]
tip <- args[4]
deforestation <- args[5]
time_period <- args[6]

if (is.na(start_index) || is.na(end_index) || start_index < 1 || end_index < start_index || end_index > 100) {
  stop("MC indices must be within 1 to 100 and start_index must not exceed end_index.")
}

taxa <- c("amphibians", "mammals", "reptiles", "birds_resident")
scenario_dir <- file.path(
  DATA_ROOT, "intermediate", "07_postprocess_data",
  "species_richness_from_SDM_projections", "results_ETresid",
  paste0(ssp, "_", tip, "_", deforestation), time_period
)
if (!dir.exists(scenario_dir)) {
  stop("Taxon-level richness directory does not exist: ", scenario_dir)
}

taxon_file <- function(taxon, kind, mc_id) {
  file.path(scenario_dir, paste0(kind, "_species_richness_MC_", taxon, mc_id, ".tif"))
}

sum_taxa <- function(kind, mc_id) {
  files <- vapply(taxa, taxon_file, character(1), kind = kind, mc_id = mc_id)
  missing <- files[!file.exists(files)]
  if (length(missing) > 0) {
    stop(
      "MC ", mc_id, " is incomplete for ", kind, ". Missing file(s):\n",
      paste(missing, collapse = "\n")
    )
  }

  rasters <- lapply(files, terra::rast)
  reference <- rasters[[1]]
  for (raster in rasters[-1]) {
    if (!terra::compareGeom(reference, raster, stopOnError = FALSE)) {
      stop("Taxon rasters do not share the same grid for ", kind, ", MC ", mc_id)
    }
  }

  total <- reference
  for (raster in rasters[-1]) {
    total <- total + raster
  }
  total
}

for (mc_i in start_index:end_index) {
  message("Aggregating all taxa for MC sample ", mc_i)

  total_historic <- sum_taxa("historic", mc_i)
  total_future <- sum_taxa("future", mc_i)
  total_delta <- total_future - total_historic

  terra::writeRaster(
    total_historic,
    file.path(scenario_dir, paste0("historic_species_richness_MC_all_species_", mc_i, ".tif")),
    overwrite = TRUE
  )
  terra::writeRaster(
    total_future,
    file.path(scenario_dir, paste0("future_species_richness_MC_all_species_", mc_i, ".tif")),
    overwrite = TRUE
  )
  terra::writeRaster(
    total_delta,
    file.path(scenario_dir, paste0("delta_species_richness_MC_all_species_", mc_i, ".tif")),
    overwrite = TRUE
  )
}