library(terra)

data_root <- Sys.getenv("AMAZON_DATA_DIR")
if (data_root == "") {
  stop("Set AMAZON_DATA_DIR before running this script.")
}

bird_type <- "birds_resident"
birds_seasonality_map <- c(
  birds_resident = 1,
  birds_breeding = 2,
  birds_non_breeding = 3
)
bird_seasonality <- birds_seasonality_map[bird_type]

output_dir <- file.path(data_root, "intermediate", "07_postprocess_data", "figure_1", "species_richness")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Create target raster.
r_template <- rast(
  xmin = -180, xmax = 180,
  ymin = -90, ymax = 90,
  resolution = 0.5,
  crs = "EPSG:4326"
)

polygon_data_path <- file.path(data_root, "raw", "03_species_ranges", "birds", "BOTW_2024_2.gpkg")
out_file <- file.path(output_dir, paste0("SR_", bird_type, "_05deg.tif"))

v <- vect(polygon_data_path)
v <- v[v$presence %in% c(1, 2, 3), ]
v <- v[v$origin %in% c(1, 2), ]
v <- v[v$seasonal %in% bird_seasonality, ]

# Now reduce columns.
v <- v[, "sci_name"]

# Calculate SR.
species_names <- unique(v$sci_name)
sr <- rast(r_template)
values(sr) <- 0

for (sp in species_names) {
  sp_poly <- v[v$sci_name == sp, ]
  cov <- rasterize(sp_poly, r_template, field = 1, cover = TRUE, background = 0)
  sr <- sr + (cov > 0)
}

writeRaster(sr, out_file, overwrite = TRUE)
