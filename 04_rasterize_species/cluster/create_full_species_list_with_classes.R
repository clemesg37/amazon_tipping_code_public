library(terra)
library(dplyr)

DATA_ROOT <- Sys.getenv("AMAZON_DATA_DIR")
if (DATA_ROOT == "") stop("Set AMAZON_DATA_DIR before running this script.")

raster_root <- file.path(DATA_ROOT, "intermediate", "04_rasterized_species")
base_paths <- list(
  amphibians = file.path(raster_root, "amphibians"),
  mammals = file.path(raster_root, "mammals"),
  reptiles = file.path(raster_root, "reptiles"),
  birds_resident = file.path(raster_root, "birds", "resident"),
  birds_breeding = file.path(raster_root, "birds", "breeding"),
  birds_non_breeding = file.path(raster_root, "birds", "non_breeding")
)

# Empty data set for results
results <- data.frame(
  Species = character(),
  type = character(),
  seasonality = character(),
  PresencePoints = integer(),
  area_km2 = numeric(),
  stringsAsFactors = FALSE
)

# Loop over all types
for (species_type in names(base_paths)) {
  base_path <- base_paths[[species_type]]
  rds_path <- file.path(base_path, paste0("Selected_species_raster_path_", species_type, ".rds"))
  
  if (!file.exists(rds_path)) {
    message("Skipping missing file: ", rds_path)
    next
  }
  
  raster_paths <- readRDS(rds_path)
  
  # Type
  type <- case_when(
    grepl("amphibian", species_type) ~ "amphibians",
    grepl("mammal", species_type) ~ "mammals",
    grepl("reptile", species_type) ~ "reptiles",
    grepl("bird", species_type) ~ "birds",
    TRUE ~ species_type
  )
  
  # Seasonality
  seasonality <- case_when(
    grepl("non_breeding", species_type) ~ "non_breeding",
    grepl("breeding", species_type) ~ "breeding",
    grepl("resident", species_type) ~ "resident",
    TRUE ~ NA_character_
  )
  
  # Loop over all species
  for (species_name in names(raster_paths)) {
    raster_path <- raster_paths[[species_name]]
    
    if (!file.exists(raster_path)) {
      message("Missing raster: ", raster_path)
      next
    }
    
    species_raster <- rast(raster_path)
    presence_cells <- which(values(species_raster) == 1)
    presence_count <- length(presence_cells)
    
    if (presence_count == 0) next
    
    cell_areas <- cellSize(species_raster, unit = "km")
    total_area_km2 <- sum(values(cell_areas)[presence_cells], na.rm = TRUE)
    
    results <- rbind(
      results,
      data.frame(
        Species = species_name,
        type = type,
        seasonality = seasonality,
        PresencePoints = presence_count,
        area_km2 = total_area_km2,
        stringsAsFactors = FALSE
      )
    )
  }
}

# Create classes
final_data <- results %>%
  mutate(class = case_when(
    PresencePoints >= 50 & PresencePoints <= 150 ~ "supersmall",
    PresencePoints >= 151 & PresencePoints <= 400 ~ "small",
    PresencePoints >= 401 & PresencePoints <= 1000 ~ "medium",
    PresencePoints >= 1001 & PresencePoints <= 2500 ~ "large",
    PresencePoints >= 2501 ~ "superlarge",
    TRUE ~ NA_character_
  ))

# Optional check
print(table(final_data$class, useNA = "ifany"))

output_path <- file.path(raster_root, "full_species_list_amazon_updated.csv")
write.csv(final_data, output_path, row.names = FALSE)

print(paste("Final species list with classes saved to:", output_path))
