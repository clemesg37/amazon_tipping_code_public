##### Load packages
library(terra)     
library(sf)        
library(dplyr)    
library(sp) 
library(s2)


##### Set start and end index, class value, and run for batch script 
args <- commandArgs(trailingOnly = TRUE)
start_index <- as.numeric(args[1])
end_index <- as.numeric(args[2])
species_type <- args[3]
class_value <- args[4]   

print(paste("Processing species from", start_index, "to", end_index))
print(paste("Species type:", species_type))
print(paste("Class:", class_value))

DATA_ROOT <- Sys.getenv("AMAZON_DATA_DIR")
if (DATA_ROOT == "") stop("Set AMAZON_DATA_DIR before running this script.")

##### Choose list of species 

selected_species_df <- read.csv(file.path(DATA_ROOT, "intermediate", "04_rasterize_species", "full_species_list_amazon_updated.csv"))


# Determine type 
taxon_type <- case_when(
  grepl("amphibian", species_type) ~ "amphibians",
  grepl("mammal", species_type) ~ "mammals",
  grepl("reptile", species_type) ~ "reptiles",
  grepl("bird", species_type) ~ "birds",
  TRUE ~ species_type
)

# Determine seasonality (ONLY relevant for birds)
bird_seasonality <- case_when(
  grepl("birds_resident", species_type) ~ "resident",
  grepl("birds_non_breeding", species_type) ~ "non_breeding",
  grepl("birds_breeding", species_type) ~ "breeding",
  TRUE ~ NA_character_
)

# Select species
if (taxon_type == "birds") {
  selected_species_set <- selected_species_df %>%
    filter(
      type == taxon_type,
      seasonality == bird_seasonality,
      class == class_value
    ) %>%
    select(Species, PresencePoints, area_km2)
} else {
  selected_species_set <- selected_species_df %>%
    filter(
      type == taxon_type,
      class == class_value
    ) %>%
    select(Species, PresencePoints, area_km2)
}


# Choose set of species for selected indices of batch script
selected_species_set <- selected_species_set[start_index:end_index, ]

## Calibrate the area where pseudo-absence points are created

# Find the smallest area
A_min <- min(selected_species_df$area_km2, na.rm = TRUE)

# Define maximal area
A_max <- 10^6 

# Define minimal length of the buffer radius
r_min <- 300 

# Calculate radius for maximal area 
r_max = (sqrt(11) - 1) / sqrt(pi) * sqrt(A_max)

# Calculate parameters of radius calibration function

a = (r_max - r_min) / (sqrt(A_max) - sqrt(A_min))
b = r_min - sqrt(A_min) * a

# Define radius function
buffer_radius_function <- function(A) {
  # Calculate the radius
  r <- a * sqrt(A) + b
  # Multiply the result by 1000 and convert to integer
  r_int <- as.integer(r * 1000)
  return(r_int)
}

##### Load relevant datasets

### Historic bioclimatic variables
historic_bioclimatic_vars <- rast(file.path(DATA_ROOT, "intermediate", "02_bioclimatic_variables", "bioclimatic_variables_historic_ERA5_1980_2014.nc"))

# base bath
base_path <- file.path(DATA_ROOT, "intermediate", "02_bioclimatic_variables")

# SSPs
ssps <- c("ssp245", "ssp370")

# Tipping
tipping <- c("notip", "tip")

# Deforestation
deforestation <- c("no_deforestation", "deforestation")

# time periods
periods <- c("2030_2044", "2050_2069", "2080_2099")

# List to save the raster
data_list <- list()


# Load all future datasets
for (ssp in ssps) {
  for (tip in tipping) {
    
    # when tip=="tip" use both tipping scenarios, else only use the no_deforestation scenario
    defor_values <- if (tip == "tip") deforestation else "no_deforestation"
    
    for (defor in defor_values) {
      for (period in periods) {
        
        # Define file path
        if (tip == "tip") {
          file_path <- file.path(base_path, ssp, tip, defor, paste0("bioclim_vars_ETresid_", period, ".nc"))
        }
        else {
          file_path <- file.path(base_path, ssp, tip, paste0("bioclim_vars_ETresid_", period, ".nc"))
        }
        
        # Load the dataset
        if (file.exists(file_path)) {
          var_name <- paste0("future_bioclimatic_vars_", ssp, "_", tip, "_", defor, "_", period)
          data_list[[var_name]] <- rast(file_path)
          message("Loaded: ", var_name)
        } else {
          warning("File not found: ", file_path)
        }
        
      }
    }
  }
}


# Activate s2 option for spherical geometry
sf_use_s2(TRUE)

# Set CRS (Coordinate Reference System) to WGS84
crs.wgs84 <- st_crs(4326)  # WGS84 coordinate system

# Base path of rds files
raster_root <- file.path(DATA_ROOT, "intermediate", "04_rasterize_species", "rasterized_species")
base_paths <- list(
  amphibians = file.path(raster_root, "amphibians"),
  mammals = file.path(raster_root, "mammals"),
  reptiles = file.path(raster_root, "reptiles"),
  birds = file.path(raster_root, "birds")
)

if (taxon_type == "birds") {
  rds_path <- file.path(base_paths[[taxon_type]], bird_seasonality, paste0("Selected_species_raster_path_", taxon_type, "_", bird_seasonality, ".rds"))
} else {
  rds_path <- file.path(base_paths[[taxon_type]], paste0("Selected_species_raster_path_", taxon_type, ".rds"))
}

# Load 
raster_paths <- readRDS(rds_path)


output_dir <- file.path(DATA_ROOT, "intermediate", "05_selected_bioclimatic_variables", "data")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

for (i in seq_len(nrow(selected_species_set))) {
  
  #tryCatch({
  selected_species <- selected_species_set$Species[i]
  print(paste("Selected species", selected_species))
  selected_raster_path <- raster_paths[[selected_species]]  
  species_raster <- rast(selected_raster_path) 
  presence_points <- as.data.frame(xyFromCell(species_raster, which(values(species_raster) == 1)))  
  colnames(presence_points) <- c("x", "y")  
  presence_points_sf <- st_as_sf(presence_points, coords = c("x", "y"), crs = crs.wgs84)
  presence_points_sf <- st_make_valid(presence_points_sf)
  num_presence_points <- nrow(presence_points_sf)
  #print(paste("Number of used presence points:", num_presence_points, "points."))
  
  if (num_presence_points > 50) {
    selected_points <- presence_points_sf[sample(1:num_presence_points, 50), ]
  } else {
    selected_points <- presence_points_sf
  }
  
  A <- selected_species_set %>%
    filter(Species == selected_species) %>%
    pull(area_km2)
  
  #print(A)
  radius_buffer <- buffer_radius_function(A)
  #print(paste("radius buffer", radius_buffer))
  
  raster_points <- as.data.frame(xyFromCell(historic_bioclimatic_vars, 1:ncell(historic_bioclimatic_vars)))
  raster_points_sf <- st_as_sf(raster_points, coords = c("x", "y"), crs = crs.wgs84)
  #print(raster_points_sf)
  
  # Maximum possible buffer radius (half Earth equator circumference, meters)
  r_max_hard <- 40075017 / 2
  
  repeat {
    
    # Cap radius at half Earth circumference
    if (radius_buffer >= r_max_hard) {
      radius_buffer <- r_max_hard
      warning(
        paste(
          "Max buffer reached for species",
          selected_species,
          "- stopping buffer increase."
        )
      )
    }
    determine_radius <- lengths(st_is_within_distance(raster_points_sf, selected_points, dist = radius_buffer))
    valid_raster_points <- raster_points_sf[determine_radius > 0, ]
    
    bioclimatic_vars_cropped <- crop(historic_bioclimatic_vars, st_bbox(valid_raster_points))
    masked_bioclim_vars <- mask(bioclimatic_vars_cropped, vect(valid_raster_points))
    
    num_bioclim_valid_points <- sum(!is.na(values(masked_bioclim_vars[[1]])))
    #print(paste("Number of valid bioclimatic points:", num_bioclim_valid_points))
    
    if (num_bioclim_valid_points > 11 * num_presence_points) {
      break 
    }
    
    # if max radius reached but condition still not met, exit loop
    if (radius_buffer >= r_max_hard) {
      message(
        paste(
          "Condition not met even at max radius for species",
          selected_species,
          "- proceeding with max buffer."
        )
      )
      break
    }
    
    
    radius_buffer <- radius_buffer * 1.2  
    print(paste("Increasing buffer to:", radius_buffer))
  }
  
  # Save historic variables 
  historic_filename <- file.path(output_dir, paste0(selected_species, "_historic.tif"))
  writeRaster(masked_bioclim_vars, historic_filename, overwrite = TRUE)
  print(paste("Saved historic variables to:", historic_filename))
  
  # Save future variables
  for (ssp in ssps) {
    for (tip in tipping) {
      
      # when tip=="tip" use both tipping scenarios, else only use the no_deforestation scenario
      defor_values <- if (tip == "tip") deforestation else "no_deforestation"
      
      for (defor in defor_values) {
        for (period in periods) {
          future_var_name <- paste0("future_bioclimatic_vars_", ssp, "_", tip, "_", defor, "_", period)
        
        if (!is.null(data_list[[future_var_name]])) {
          crop_future_bioclim_vars <- crop(data_list[[future_var_name]], st_bbox(valid_raster_points))
          masked_future_bioclim_vars <- mask(crop_future_bioclim_vars, vect(valid_raster_points))
          
          future_filename <- file.path(output_dir, paste0(selected_species, "_", ssp, "_", tip, "_", defor, "_", period, ".tif"))
          writeRaster(masked_future_bioclim_vars, future_filename, overwrite = TRUE)
          print(paste("Saved future variables to:", future_filename))
        }
      }
    }
    }
  }
    
  #}, error = function(e) {
  #  message(paste("Error at Species", i, "- go to next"))
  #})
}




