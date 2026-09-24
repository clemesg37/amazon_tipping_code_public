library(fs)
library(tools)

DATA_ROOT <- Sys.getenv("AMAZON_DATA_DIR")
if (DATA_ROOT == "") stop("Set AMAZON_DATA_DIR before running this script.")

raster_root <- file.path(DATA_ROOT, "intermediate", "04_rasterize_species", "rasterized_species")
base_paths <- list(
  amphibians = file.path(raster_root, "amphibians"),
  mammals = file.path(raster_root, "mammals"),
  reptiles = file.path(raster_root, "reptiles"),
  birds_resident = file.path(raster_root, "birds", "resident"),
  birds_breeding = file.path(raster_root, "birds", "breeding"),
  birds_non_breeding = file.path(raster_root, "birds", "non_breeding")
)

for (species_type in names(base_paths)) {
  output_dir <- base_paths[[species_type]]

  raster_files <- dir_ls(output_dir, glob = "*.tif", recurse = TRUE)

  raster_paths <- setNames(as.list(raster_files), file_path_sans_ext(basename(raster_files)))
  output_file <- file.path(output_dir, paste0("Selected_species_raster_path_", species_type, ".rds"))
  saveRDS(raster_paths, file = output_file)
}
