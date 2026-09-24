library(terra)
library(sf)
library(dplyr)
library(readr)
library(stringr)

# Choose parameters based on arguments
args <- commandArgs(trailingOnly = TRUE)
species_type <- args[1]
part <- as.numeric(args[2])

# Minimum number of pixels
min_pixel <- 50

DATA_ROOT <- Sys.getenv("AMAZON_DATA_DIR")
if (DATA_ROOT == "") stop("Set AMAZON_DATA_DIR before running this script.")

base_output_dir <- file.path(DATA_ROOT, "intermediate", "04_rasterize_species", "rasterized_species")

if (grepl("^birds", species_type)) {
  saisonality <- case_when(
    grepl("birds_resident", species_type) ~ "resident",
    grepl("birds_breeding", species_type) ~ "breeding",
    grepl("birds_non_breeding", species_type) ~ "non_breeding"
  )
  output_dir <- file.path(base_output_dir, "birds", saisonality)
  
} else if (grepl("^reptiles", species_type)) {
  output_dir <- file.path(base_output_dir, "reptiles")
  
} else {
  output_dir <- file.path(base_output_dir, species_type)
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# Load the historical ERA5 grid as a rasterization template.
bioclim_rast <- rast(file.path(
  DATA_ROOT, "intermediate", "01_a_historical",
  "T_AMAZON_base_period_historic.nc"
))
target_crs <- crs(bioclim_rast)

# Shapefile path
species_input_dir <- file.path(DATA_ROOT, "intermediate", "03_species_data")
shapefile_path_map <- list(
  amphibians = file.path(species_input_dir, "amphibians", "species_for_modelling", paste0("filtered_species_", part, ".gpkg")),
  mammals = file.path(species_input_dir, "mammals", "species_for_modelling", paste0("filtered_species_", part, ".gpkg")), 
  reptiles_part1 = file.path(species_input_dir, "reptiles_part1", "species_for_modelling", paste0("filtered_species_", part, ".gpkg")),
  reptiles_part2 = file.path(species_input_dir, "reptiles_part2", "species_for_modelling", paste0("filtered_species_", part, ".gpkg")),
  birds_resident = file.path(species_input_dir, "birds", "resident", "species_for_modelling", paste0("filtered_species_", part, ".gpkg")),
  birds_breeding = file.path(species_input_dir, "birds", "breeding", "species_for_modelling", paste0("filtered_species_", part, ".gpkg")),
  birds_non_breeding = file.path(species_input_dir, "birds", "non_breeding", "species_for_modelling", paste0("filtered_species_", part, ".gpkg"))
)

# Define shapefile path
shapefile_path <- shapefile_path_map[[species_type]]

# Read shapefile
species_sf <- st_read(shapefile_path)

# Set correct CRS
species_sf <- st_transform(species_sf, target_crs)

# Define list of all species in dataset
species_list <- unique(species_sf$sci_name)

for (species_name in species_list) {
  filtered <- species_sf %>%
    filter(sci_name == species_name)
  
  # Construct vector
  species_vect <- vect(filtered)
  
  # Rasterize
  species_raster <- rasterize(species_vect, bioclim_rast, cover = TRUE)
  
  # Make binary
  species_raster_bin <- classify(species_raster, cbind(0.5, 1, 1), others = NaN)
  
  # Count pixels
  pixel_count <- sum(values(species_raster_bin) == 1, na.rm = TRUE)
  
  # Only save raster if enough presence points are given
  if (pixel_count >= min_pixel) {
    raster_path <- file.path(output_dir, paste0(gsub(" ", "_", species_name), ".tif"))
    writeRaster(species_raster_bin, filename = raster_path, overwrite = TRUE)
    message("Saved: ", species_name, " | number of pixel: ", pixel_count)
  } else {
    message("Not saved under: ", species_name, " | number of pixel: ", pixel_count)
  }
}
