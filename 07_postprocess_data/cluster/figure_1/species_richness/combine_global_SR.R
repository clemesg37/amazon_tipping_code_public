library(terra)

data_root <- Sys.getenv("AMAZON_DATA_DIR")
if (data_root == "") {
  stop("Set AMAZON_DATA_DIR before running this script.")
}

input_dir <- file.path(
  data_root, "intermediate", "07_postprocess_data", "figure_1", "species_richness"
)

input_files <- file.path(
  input_dir,
  c(
    "SR_amphibians_05deg.tif",
    "SR_mammals_05deg.tif",
    "SR_reptiles_part1_05deg.tif",
    "SR_reptiles_part2_05deg.tif",
    "SR_birds_resident_05deg.tif"
  )
)

sr_rasters <- lapply(input_files, rast)
sr_world_all_taxa <- Reduce(`+`, sr_rasters)

output_file <- file.path(input_dir, "SR_world_all_taxa_land_05deg.tif")
writeRaster(sr_world_all_taxa, output_file, overwrite = TRUE)
