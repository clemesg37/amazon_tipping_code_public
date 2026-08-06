library(terra)

data_root <- Sys.getenv("AMAZON_DATA_DIR")
if (data_root == "") {
  stop("Set AMAZON_DATA_DIR before running this script.")
}

# Args
args <- commandArgs(trailingOnly = TRUE)
species_type <- args[1]

if (species_type %in% c("reptiles_part1", "reptiles_part2")) {
  species_type_capital <- toupper(species_type)
  polygon_data_path <- file.path(data_root, "raw", "03_species_ranges", "iucn", "REPTILES", paste0(species_type_capital, ".shp"))
} else {
  species_type_capital <- toupper(species_type)
  polygon_data_path <- file.path(data_root, "raw", "03_species_ranges", "iucn", species_type_capital, paste0(species_type_capital, ".shp"))
}

output_dir <- file.path(data_root, "intermediate", "07_postprocess_data", "figure_1", "species_richness")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Create target raster.
r_template <- rast(
  xmin = -180, xmax = 180,
  ymin = -90, ymax = 90,
  resolution = 0.5,
  crs = "EPSG:4326"
)

# Read shapefile as vector (reads data only when used).
v <- vect(polygon_data_path)

# Attribute filters (IUCN standard).
v <- v[v$presence %in% c(1, 2, 3), ]
v <- v[v$origin %in% c(1, 2), ]
v <- v[v$seasonal %in% c(1, 2, 3), ]

# Keep only species name column to reduce memory.
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

save_path <- file.path(output_dir, paste0("SR_", species_type, "_05deg.tif"))
writeRaster(sr, save_path, overwrite = TRUE)
