##### Load packages
library(terra)     
library(sf)        
library(fuzzySim)   
library(biomod2)   
library(sp) 
library(stringr)
library(s2)
library(ggplot2)
library(blockCV)
library(ggplot2)
library(dplyr)


##### Set start and end index, class value, and run for batch script 
args <- commandArgs(trailingOnly = TRUE)
start_index <- as.numeric(args[1])
end_index <- as.numeric(args[2])
species_type <- args[3]

print(paste("Processing species from", start_index, "to", end_index))
print(paste("Species type:", species_type))

DATA_ROOT <- Sys.getenv("AMAZON_DATA_DIR")
if (DATA_ROOT == "") stop("Set AMAZON_DATA_DIR before running this script.")
raster_root <- file.path(DATA_ROOT, "intermediate", "04_rasterized_species")
selected_bioclim_dir <- file.path(DATA_ROOT, "intermediate", "05_selected_bioclimatic_variables", "data")
amazon_mask_path <- file.path(DATA_ROOT, "intermediate", "01_c_noresm2", "amazon_mask", "amazon_mask.tif")
mc_sample_path <- file.path(DATA_ROOT, "intermediate", "06_sdm", "mc_samples", "MC_sample.csv")
models_root <- file.path(DATA_ROOT, "intermediate", "06_sdm", "models")

##### Choose list of species 

# List of species to include in hyperparamter tuning 
selected_species_df <- read.csv(file.path(raster_root, "full_species_list_amazon_updated.csv"))


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

# Choose set of species
if (taxon_type == "birds") {
  selected_species_set <- selected_species_df %>%
    filter(
      type == taxon_type,
      seasonality == bird_seasonality
    ) %>%
    select(Species, PresencePoints, area_km2)
} else {
  selected_species_set <- selected_species_df %>%
    filter(
      type == taxon_type
    ) %>%
    select(Species, PresencePoints, area_km2)
}


# Choose set of species for selected indices of batch script
selected_species_set <- selected_species_set[start_index:end_index, ]

print(paste("Processing species from", start_index, "to", end_index))
print(paste("Species type:", species_type))

### Set parameters

# Threshold for correlation in collinearity analysis (reduces number of bioclimatic variables)
cor_thresh <- 0.8

# Number of folds of spatial CV
k_folds <- 5 

# Define HPs
selected_hyperparams <- list(
  GLM.formula = c("simple", "quadratic"),
  GLM.interaction = c(0,1),
  GAM.formula = c("simple", "quadratic"),
  GAM.interaction = c(0,1),
  RFd.ntrees = c(500),
  RFd.mtry = c(1, 2, 3, 4),
  RFd.nodesize = c(1, 5, 10, 15, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 34, 36, 38, 40, 50, 60),
  GBM.n.trees = c(50, 100, 250, 500, 750, 1000, 1500, 2000, 2500, 3000, 3500),
  GBM.shrinkage = c(0.0005, 0.001, 0.01, 0.05, 0.1, 0.5),
  GBM.interaction.depth = c(1, 2, 5, 10),
  GBM.n.minobsinnode = c(5, 10, 20, 30, 40, 50)
)


# Tuning parameters for regression models

# GLM
GLM.formula <- selected_hyperparams$GLM.formula
GLM.interaction <- selected_hyperparams$GLM.interaction

# GAM
GAM.formula <- selected_hyperparams$GAM.formula
GAM.interaction <- selected_hyperparams$GAM.interaction

# RFd
RFd.ntrees <- selected_hyperparams$RFd.ntrees
RFd.mtry <- selected_hyperparams$RFd.mtry
RFd.nodesize <- selected_hyperparams$RFd.nodesize

# GBM
GBM.n.trees <- selected_hyperparams$GBM.n.trees
GBM.shrinkage <- selected_hyperparams$GBM.shrinkage
GBM.interaction.depth <- selected_hyperparams$GBM.interaction.depth
GBM.n.minobsinnode <- selected_hyperparams$GBM.n.minobsinnode


### CH0OSE ONLY ONE SPECIFIC SPECIES FOR TESTING

#selected_species_name <- "Allobates_fuscellus"
#selected_species_name <- "Rhinella_dapsilis"

#selected_species_set <- selected_species_df %>% filter(Species == selected_species_name) %>% select(Species, PresencePoints)

#selected_species_name <- selected_species_set$Species

#num_presence_points <- selected_species_set$PresencePoints

## Number of pseudo absence points as a multiple of the number of presence points
prec_number_pseudo_absences <- 10

## Number of cores used for parallel computing:
nb.cpu = 64

##### Load relevant datasets

# Activate s2 option for spherical geometry
sf_use_s2(TRUE)

# Set CRS (Coordinate Reference System) to WGS84
crs.wgs84 <- st_crs(4326)  # WGS84 coordinate system

# Base path of rds files
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

# Start loop of all species 
for (j in seq_len(nrow(selected_species_set))) {
  
 
  # Select species
  selected_species_name <- selected_species_set$Species[j]
  
  print(selected_species_name)
  
  # Get the path of the raster for the selected species
  selected_raster_path <- raster_paths[[selected_species_name]]  
  
  # Load the species raster
  species_raster <- rast(selected_raster_path) 
  
  # Extract presence points from the raster
  presence_points <- as.data.frame(xyFromCell(species_raster, which(values(species_raster) == 1)))  
  
  # Rename columns to 'x' and 'y'
  colnames(presence_points) <- c("x", "y")  
  
  # Convert coordinates to an sf object 
  presence_points_sf <- st_as_sf(presence_points, coords = c("x", "y"), crs = crs.wgs84)
  
  # Clean presence points
  presence_points_sf <- st_make_valid(presence_points_sf)
  
  # Count the number of presence points
  num_presence_points <- nrow(presence_points_sf)
  
  
  print(paste("Number of used presence points:", num_presence_points, "points."))
  
  
  # Load the masked out bioclimatic_vars
  historic_var_path <- file.path(selected_bioclim_dir, 
                                 paste0(selected_species_name, "_historic.tif"))
  masked_bioclim_vars <- rast(historic_var_path)
  
  # Implement a check if enough points are included
  
  # Define the directory where models should be saved
  custom_directory <- models_root
  dir.create(custom_directory, recursive = TRUE, showWarnings = FALSE)
  
  # Set the working directory to the custom directory (optional)
  setwd(custom_directory)
  
  # Define species with point
  species_name_with_point <- gsub("_", "\\.", selected_species_name)
  
  # Define output folder
  outputFolder <- file.path(custom_directory, species_name_with_point)
  
  ############## PART 3: Correct for collinearity ############################
  
  # Convert the masked bioclimatic variables to a DataFrame
  bioclim_data <- as.data.frame(masked_bioclim_vars, na.rm = TRUE)  # Convert raster data to a data frame, removing NA values
  
  ## Threshold for correlation in collinearity analysis (reduces number of bioclimatic variables)
  
  # Perform collinearity selection using corSelect
  selected_vars <- corSelect(
    # Input data frame containing bioclimatic variables
    data = bioclim_data,               
    # Specify columns with predictor variables
    var.cols = 1:ncol(bioclim_data),  
    # Correlation threshold for variable selection
    cor.thresh = cor_thresh,   
    # Criterion for variable selection (Variance Inflation Factor)
    select = "VIF",                    
    # Level of messages to be displayed during execution
    verbosity = 1                      
  )
  
  
  ##### PART 4: Prepare and Apply BIOMOD_FormatingData 
  
  # 1. Extract the names of the selected variables from historical data
  selected_vars_indices <- unlist(selected_vars$selected.vars)  
  
  # Print name of selected variables
  print("Selected variable indices historic:")
  print(selected_vars_indices)
  
  # 2. 
  
  # Choose specific variables of historic bioclimatic variables that are used for training of the models on the calibration area
  selected_bioclim_vars <- masked_bioclim_vars[[selected_vars_indices]]
  
  ## Plot selected bioclimatic variables next to each other (with IUCN range polygon)
  
  
  #iucn_ranges <- vect(iucn_ranges_path)
  
  # Select species 
  #iucn_range <- iucn_ranges[iucn_ranges$sci_name == gsub("_", " ", selected_species_name), ]
  
  #plot_dir <- file.path(outputFolder, "plots", "historic_bioclim_vars")
  
  #if (!dir.exists(plot_dir)) {
  #  dir.create(plot_dir, recursive=TRUE)
  #}
  
  
  #for (selected_idx in selected_vars_indices) {
  #  output_path <- file.path(plot_dir, paste0(selected_idx, ".png"))
  #  png(filename = output_path, width = 2000, height = 1600, res = 300, type = "cairo")
  #  plot(selected_bioclim_vars[[selected_idx]], main = selected_idx)
  #  lines(iucn_range, col = "black", lwd = 1.5)
  #  dev.off()
  #}
  # 3. 
  
  # Convert the selected bioclimatic variables to BIOMOD2 format
  
  # For training on calibration
  
  expl_var <- as(selected_bioclim_vars, "SpatRaster")  # Convert to SpatRaster for BIOMOD2
  
  # Mask NaN
  expl_var <- mask(expl_var, !is.na(expl_var))
  
  # Change format of presence points
  sampled_presence_points <- st_coordinates(presence_points_sf)
  sampled_presence_points_df <- as.data.frame(sampled_presence_points)
  colnames(sampled_presence_points_df) <- c("x", "y")
  
  
  # 4. Convert presence points to SpatialPointsDataFrame
  resp_var <- SpatialPointsDataFrame(
    # Use the sampled presence points coordinates
    coords = sampled_presence_points_df,  
    # Create a data frame for presence data
    data = data.frame(d = rep(1, nrow(sampled_presence_points_df))),  
    # Set the projection string to WGS84
    proj4string = CRS(crs.wgs84$proj4string)  
  )
  
  
  # Create a dataset with all the data for final model training (not hyperparamter tuning)
  
  # 5. Apply BIOMOD_FormatingData with desired parameters
  biomod_data_final_model <- BIOMOD_FormatingData(
    # Converted presence points as SpatialPointsDataFrame
    resp.var = resp_var,               
    # Selected bioclimatic variables
    expl.var = expl_var,               
    # x and y coordinates of presence data
    resp.xy = as.data.frame(st_coordinates(presence_points_sf)),  
    # Name of the target species
    resp.name = selected_species_name, 
    # Number of pseudo-absence repetitions
    PA.nb.rep = 1,   
    # Number of pseudo-absences (create two sets depending on algorithm)
    PA.nb.absences = c(as.integer(10 * num_presence_points)),            
    # Strategy for selecting pseudo-absences 
    PA.strategy = 'random',
    # 
  )
  
  coords <- biomod_data_final_model@coord
  occ_raw <- biomod_data_final_model@data.species
  
  # replace NA by zeros
  occ <- ifelse(is.na(occ_raw), 0, occ_raw)
  
  # Combine in dataframe
  occ_df <- data.frame(coords, occ = occ)
  
  # Create sf object in lon/lat
  pa_data_ll <- sf::st_as_sf(
    occ_df,
    coords = c("x", "y"),
    crs = 4326
  )
  
  # For blockCV reproject to local coordinate system
  
  centroid <- sf::st_coordinates(
    sf::st_centroid(sf::st_union(pa_data_ll))
  )
  
  local_crs <- sprintf(
    "+proj=aeqd +lat_0=%f +lon_0=%f +datum=WGS84 +units=m +no_defs",
    centroid[2], centroid[1]
  )
  
  pa_data <- sf::st_transform(pa_data_ll, local_crs)
  
  # Estimate the spatial autocorrelation range
  max_size <- 5e6
  
  message("Estimating spatial autocorrelation range (projected CRS)...")
  
  range <- cv_spatial_autocor(
    x = pa_data,
    column = "occ",
    plot = TRUE
  )
  
  # Set initial size of autocorrelation length
  initial_size <- min(range$range, max_size)
  current_size <- initial_size
  
  # Define check functions
  
  # It checks that each training set contains at least 65 % of data points
  # It checks that each test set contains at least 10 %
  check_folds_ok <- function(records_df, pa_data, train_min = 0.65, test_min = 0.1) {
    
    n <- sum(pa_data$occ == 1)
    
    train_frac <- records_df$train_1 / n
    test_frac  <- records_df$test_1  / n
    
    cond_train <- all(train_frac >= train_min)
    cond_test  <- all(test_frac  >= test_min)
    
    cond_train && cond_test
  }

  
  # Define function that tries to create blockCV
  safe_cv_spatial <- function(size) {
    try({
      cv_spatial(
        x = pa_data,
        column = "occ",
        #r = selected_bioclim_vars_proj,
        k = k_folds,
        size = size,
        selection = "random",
        iteration = 50,
        progress = FALSE,
        biomod2 = TRUE,
        raster_colors = terrain.colors(10, rev = TRUE)
      )
    }, silent = TRUE)
  }
  
  
  # First try
  message("Trying first cv_spatial() with size = ", current_size)
  
  scv_try <- safe_cv_spatial(current_size)
  
  # Main loop repeat cv_spatial() until ratio of training/test data set is fullfiled
  repeat {
    
    if (inherits(scv_try, "try-error")) {
      message("cv_spatial() error: ", scv_try)
      
      if (grepl("k is bigger than the number of spatial blocks", scv_try)) {
        message("Too few blocks. Reducing block size...")
      }
      
      current_size <- current_size * 0.8
      scv_try <- safe_cv_spatial(current_size)
      next
    }
    
    rec <- scv_try$records
    
    if (check_folds_ok(rec, pa_data)) {
      scv_final <- scv_try
      message("Final block size: ", current_size)
      break
    } else {
      message("Fold conditions not met. Reducing size...")
      current_size <- current_size * 0.8
      scv_try <- safe_cv_spatial(current_size)
    }
    
    if (current_size < 1000) {
      stop("Block size became too small (< 1000 m). Something else is wrong.")
    }
  }
  
  
  #windows()
  #cv_plot(
  #  cv = scv_final, # cv object
  #  x = pa_data, # species spatial data
  #  num_plots = 1:4 # three of folds to plot
  #)
  
  
  
  ## Plot cv folds 
  #plot_dir <- file.path(outputFolder, "plots_blockCV", "cvfold_single_plots")
  
  #if (!dir.exists(plot_dir)) {
  #  dir.create(plot_dir, recursive=TRUE)
  #}
  
  # --- Extract train/test indices for Fold 1 ---
  #for (run in 2:2) {
  #  
  #  #output_path_train <- file.path(plot_dir, paste0("train_fold_", run, ".png"))
  #  #output_path_test <- file.path(plot_dir, paste0("test_fold_", run, ".png"))
  #  
  #  train_indices <- scv_final$folds_list[[run]][[1]]  # first element = training indices
  #  test_indices  <- scv_final$folds_list[[run]][[2]]  # second element = testing indices
  #  
  #  # --- Subset data for each set ---
  #  train_data <- pa_data[train_indices, ]
  #  test_data  <- pa_data[test_indices, ]
  #  
  #  # --- Plot 1: Training set ---
  #  
  #  p_train <- ggplot() +
  #    geom_sf(data = train_data %>% filter(occ == 0), color = "blue", size = 2, alpha = 0.7) +
  #    geom_sf(data = train_data %>% filter(occ == 1), color = "red", size = 2, alpha = 0.7) +
  #    labs(
  #      title = paste0("Fold ", run, "– Training Set"),
  #      subtitle = "Blue = Absence, Red = Presence",
  #      x = "Longitude", y = "Latitude"
  #    ) +
  #    theme_bw() +
  #    theme(
  #      plot.title = element_text(size = 16, face = "bold"),
  #      plot.subtitle = element_text(size = 12)
  #    )
  #  
  #  # --- Plot 2: Test set ---
  #  p_test <- ggplot() +
  #    geom_sf(data = test_data %>% filter(occ == 0), color = "blue", size = 2, alpha = 0.7) +
  #    geom_sf(data = test_data %>% filter(occ == 1), color = "red", size = 2, alpha = 0.7) +
  #    labs(
  #      title = paste0("Fold ", run, "- Test Set"),
  #      subtitle = "Blue = Absence, Red = Presence",
  #      x = "Longitude", y = "Latitude"
  #    ) +
  #    theme_bw() +
  #    theme(
  #      plot.title = element_text(size = 16, face = "bold"),
  #      plot.subtitle = element_text(size = 12)
  #    )
  #  
  #  #print(p_train)
  #  #print(p_test)
  #  #ggsave(output_path_train, plot = p_train, width = 7, height = 6, dpi = 300)
  #  #ggsave(output_path_test,  plot = p_test,  width = 7, height = 6, dpi = 300)
  #  
  #}
  
  # Define spatial cv folds
  spatial_cv_folds <- scv_final$biomod_table
  colnames(spatial_cv_folds) <- paste0("_PA1_RUN", 1:ncol(spatial_cv_folds))
  
  # Start HP tuning 
  
  ############ GLM #####################################################
  
  # Create grid of all HP combinations
  hyperparameter_grid_GLM <- expand.grid(
    forumla = GLM.formula,
    interaction = GLM.interaction
  )
  
  # Create a folder to store data
  evaluation_results_folder <- file.path(outputFolder, paste0("models_evaluation_blockCV_tuning"), "GLM")
  if (!dir.exists(evaluation_results_folder)) {
    dir.create(evaluation_results_folder, recursive = TRUE)
    
  }
  
  evaluation_results_list_GLM <- list()
  
  # loop over grid
  for (i in seq_len(nrow(hyperparameter_grid_GLM))) {
    params <- hyperparameter_grid_GLM[i, ]
    
    print(paste("HP of current run:", 
                paste(names(params), params, sep = "=", collapse = ", ")))
    
    form_regression_models <- bm_MakeFormula(resp.name = biomod_data_final_model@sp.name,
                                             expl.var = head(biomod_data_final_model@data.env.var),
                                             type = params$forumla,
                                             interaction.level = params$interaction)
    
    user.GLM <- list()
    for (k in 1:k_folds) {
      user.GLM[[paste0('_PA1_RUN', k)]] <- list(formula = form_regression_models)
    }
    
    user.val <- list(
      GLM.binary.stats.glm = user.GLM
    )
    
    
    myOpt <- bm_ModelingOptions(
      data.type = 'binary',
      models = "GLM",
      strategy = "user.defined",
      user.val = user.val,
      user.base = "bigboss",
      bm.format = biomod_data_final_model,
      calib.lines = spatial_cv_folds
    )
    
    # Train and cross validate default model
    TunedOut <- BIOMOD_Modeling(
      bm.format = biomod_data_final_model,
      modeling.id = selected_species_name,
      models = "GLM",
      CV.strategy = 'user.defined',
      CV.user.table = spatial_cv_folds,
      OPT.user = myOpt,
      metric.eval = c('TSS'),
      nb.cpu = nb.cpu
    )
    
    myBiomodModelEval.tuned <- get_evaluations(TunedOut)
    myBiomodModelEval.tuned$formula = params$forumla
    myBiomodModelEval.tuned$interaction = params$interaction
    
    # Append to results list
    evaluation_results_list_GLM <- append(evaluation_results_list_GLM, list(myBiomodModelEval.tuned))
    
  }
  # Rebind and save performance for different HPs
  evaluation_results_tuning_GLM <- bind_rows(evaluation_results_list_GLM)
  
  output_path <- file.path(evaluation_results_folder, "GLM_summary_tuning.csv")
  write.csv(evaluation_results_tuning_GLM, file = output_path, row.names = FALSE)
  
  # Calculate mean over all runs for each combination of HP
  mean_over_all_runs <- evaluation_results_tuning_GLM  %>% 
    group_by(formula, interaction) %>%
    summarise(mean_validation = mean(validation, na.rm = TRUE))
  
  # Select HPs with best performance
  GLM.tuned.formula <- as.character(mean_over_all_runs[which.max(mean_over_all_runs$mean_validation),]$formula)
  GLM.tuned.interaction <- mean_over_all_runs[which.max(mean_over_all_runs$mean_validation),]$interaction
  GLM.tuned.TSS <- max(mean_over_all_runs$mean_validation)
  
  ## Finished GLM ######################################################
  
  ############ GAM #####################################################
  
  # Create grid of all HP combinations
  hyperparameter_grid_GAM <- expand.grid(
    forumla = GAM.formula,
    interaction = GAM.interaction
  )
  
  # Create a folder to store data
  evaluation_results_folder <- file.path(outputFolder, paste0("models_evaluation_blockCV_tuning"), "GAM")
  if (!dir.exists(evaluation_results_folder)) {
    dir.create(evaluation_results_folder, recursive = TRUE)
    
  }
  
  evaluation_results_list_GAM <- list()
  
  # loop over grid
  for (i in seq_len(nrow(hyperparameter_grid_GAM))) {
    params <- hyperparameter_grid_GAM[i, ]
    
    print(paste("HP of current run:", 
                paste(names(params), params, sep = "=", collapse = ", ")))
    
    form_regression_models <- bm_MakeFormula(resp.name = biomod_data_final_model@sp.name,
                                             expl.var = head(biomod_data_final_model@data.env.var),
                                             type = params$forumla,
                                             interaction.level = params$interaction)
    
    user.GAM <- list()
    for (k in 1:k_folds) {
      user.GAM[[paste0('_PA1_RUN', k)]] <- list(formula = form_regression_models)
    }
    
    user.val <- list(
      GAM.binary.mgcv.gam = user.GAM
    )
    
    
    myOpt <- bm_ModelingOptions(
      data.type = 'binary',
      models = "GAM",
      strategy = "user.defined",
      user.val = user.val,
      user.base = "bigboss",
      bm.format = biomod_data_final_model,
      calib.lines = spatial_cv_folds
    )
    
    # Train and cross validate default model
    TunedOut <- BIOMOD_Modeling(
      bm.format = biomod_data_final_model,
      modeling.id = selected_species_name,
      models = "GAM",
      CV.strategy = 'user.defined',
      CV.user.table = spatial_cv_folds,
      OPT.user = myOpt,
      metric.eval = c('TSS'),
      nb.cpu = nb.cpu
    )
    
    myBiomodModelEval.tuned <- get_evaluations(TunedOut)
    myBiomodModelEval.tuned$formula = params$forumla
    myBiomodModelEval.tuned$interaction = params$interaction
    
    # Append to results list
    evaluation_results_list_GAM <- append(evaluation_results_list_GAM, list(myBiomodModelEval.tuned))
    
  }
  # Rebind and save performance for different HPs
  evaluation_results_tuning_GAM <- bind_rows(evaluation_results_list_GAM)
  
  output_path <- file.path(evaluation_results_folder, "GAM_summary_tuning.csv")
  write.csv(evaluation_results_tuning_GAM, file = output_path, row.names = FALSE)
  
  # Calculate mean over all runs for each combination of HP
  mean_over_all_runs <- evaluation_results_tuning_GAM  %>% 
    group_by(formula, interaction) %>%
    summarise(mean_validation = mean(validation, na.rm = TRUE))
  
  # Select HPs with best performance
  GAM.tuned.formula <- as.character(mean_over_all_runs[which.max(mean_over_all_runs$mean_validation),]$formula)
  GAM.tuned.interaction <- mean_over_all_runs[which.max(mean_over_all_runs$mean_validation),]$interaction
  GAM.tuned.TSS <- max(mean_over_all_runs$mean_validation)
  
  ## Finished GAM ######################################################
  
  ## Tuning RFd ########################################################
  
  # Create grid of all HP combinations
  hyperparameter_grid_RFd <- expand.grid(
    ntrees = RFd.ntrees,
    mtry = RFd.mtry,
    nodesize = RFd.nodesize)
  
  # Create a folder to store data
  evaluation_results_folder <- file.path(outputFolder, paste0("models_evaluation_blockCV_tuning"), "RFd")
  if (!dir.exists(evaluation_results_folder)) {
    dir.create(evaluation_results_folder, recursive = TRUE)
    
  }
  
  evaluation_results_list_RFd <- list()
  
  # loop over grid
  for (i in seq_len(nrow(hyperparameter_grid_RFd))) {
    params <- hyperparameter_grid_RFd[i, ]
    
    print(paste("HP of current run:", 
                paste(names(params), params, sep = "=", collapse = ", ")))
    
    form <- bm_MakeFormula(resp.name = biomod_data_final_model@sp.name,
                           expl.var = head(biomod_data_final_model@data.env.var),
                           type = "simple",
                           interaction.level = 0)
    
    user.RFd <- list()
    for (i in 1:k_folds) {
      user.RFd[[paste0('_PA1_RUN', i)]] <- list(formula = form,
                                                ntree = 500,
                                                nodesize = params$nodesize,
                                                mtry = params$mtry)
    }
    
    user.val <- list(
      RFd.binary.randomForest.randomForest = user.RFd
    )
    
    
    myOpt <- bm_ModelingOptions(
      data.type = 'binary',
      models = "RFd",
      strategy = "user.defined",
      user.val = user.val,
      user.base = "bigboss",
      bm.format = biomod_data_final_model,
      calib.lines = spatial_cv_folds
    )
    
    # Train and cross validate default model
    TunedOut <- BIOMOD_Modeling(
      bm.format = biomod_data_final_model,
      modeling.id = selected_species_name,
      models = "RFd",
      CV.strategy = 'user.defined',
      CV.user.table = spatial_cv_folds,
      OPT.user = myOpt,
      metric.eval = c('TSS'),
      nb.cpu = nb.cpu
    )
    
    myBiomodModelEval.tuned <- get_evaluations(TunedOut)
    myBiomodModelEval.tuned$mtry = params$mtry
    myBiomodModelEval.tuned$nodesize = params$nodesize
    
    # Append to results list
    evaluation_results_list_RFd <- append(evaluation_results_list_RFd, list(myBiomodModelEval.tuned))
    
  }
  # Rebind and save performance for different HPs
  evaluation_results_tuning_RFd <- bind_rows(evaluation_results_list_RFd)
  
  evaluation_results_tuning_RFd
  output_path <- file.path(evaluation_results_folder, "RFd_summary_tuning.csv")
  write.csv(evaluation_results_tuning_RFd, file = output_path, row.names = FALSE)
  
  # Calculate mean over all runs for each combination of HP
  mean_over_all_runs <- evaluation_results_tuning_RFd  %>% 
    group_by(mtry, nodesize) %>%
    summarise(mean_validation = mean(validation, na.rm = TRUE))
  
  # Select HP with best mean performance
  RFd.tuned.mtry <- mean_over_all_runs[which.max(mean_over_all_runs$mean_validation),]$mtry
  RFd.tuned.nodesize <- mean_over_all_runs[which.max(mean_over_all_runs$mean_validation),]$nodesize
  RFd.tuned.TSS <- max(mean_over_all_runs$mean_validation)
  
  ## Finished RFd ######################################################
  
  ## Tuning GBM ########################################################
  
  # Create random sample of set of all possible HPs
  
  # Number of tested HP combinations in RS
  n_combinations <- 100
  
  # Define function to create random combinations of HP
  generate_random_hyperparameters <- function() {
    list(
      n.trees = sample(GBM.n.trees, 1),
      shrinkage = sample(GBM.shrinkage, 1),
      interaction.depth = sample(GBM.interaction.depth, 1),
      n.minobsinnode = sample(GBM.n.minobsinnode, 1)
    )
  }
  
  # Generate random combinations of HP
  random_hyperparameters <- replicate(n_combinations, generate_random_hyperparameters(), simplify = FALSE)
  
  
  # Create a folder to store data
  evaluation_results_folder <- file.path(outputFolder, paste0("models_evaluation_blockCV_tuning"), "GBM")
  if (!dir.exists(evaluation_results_folder)) {
    dir.create(evaluation_results_folder, recursive = TRUE)
    
  }
  
  evaluation_results_list_GBM <- list()
  
  # loop over grid
  for (i in seq_along(random_hyperparameters)) {
    params <- random_hyperparameters[[i]]
    
    print(paste("HP of current run:", 
                paste(names(params), params, sep = "=", collapse = ", ")))
    
    form <- bm_MakeFormula(resp.name = biomod_data_final_model@sp.name,
                           expl.var = head(biomod_data_final_model@data.env.var),
                           type = "simple",
                           interaction.level = 0)
    
    user.GBM <- list()
    for (i in 1:k_folds) {
      user.GBM[[paste0('_PA1_RUN', i)]] <- list(formula = form, 
                                                n.trees = params$n.trees,
                                                interaction.depth = params$interaction.depth,
                                                n.minobsinnode = params$n.minobsinnode,
                                                shrinkage = params$shrinkage)
    }
    
    user.val <- list(
      GBM.binary.gbm.gbm = user.GBM
    )
    
    myOpt <- bm_ModelingOptions(
      data.type = 'binary',
      models = "GBM",
      strategy = "user.defined",
      user.val = user.val,
      user.base = "bigboss",
      bm.format = biomod_data_final_model,
      calib.lines = spatial_cv_folds
    )
    
    # Train and cross validate default model
    TunedOut <- BIOMOD_Modeling(
      bm.format = biomod_data_final_model,
      modeling.id = selected_species_name,
      models = "GBM",
      CV.strategy = 'user.defined',
      CV.user.table = spatial_cv_folds,
      OPT.user = myOpt,
      metric.eval = c('TSS'),
      nb.cpu = nb.cpu
    )
    
    myBiomodModelEval.tuned <- get_evaluations(TunedOut)
    myBiomodModelEval.tuned$n.trees = params$n.trees
    myBiomodModelEval.tuned$interaction.depth = params$interaction.depth
    myBiomodModelEval.tuned$shrinkage = params$shrinkage
    myBiomodModelEval.tuned$n.minobsinnode = params$n.minobsinnode
    
    
    # Append to results list
    evaluation_results_list_GBM <- append(evaluation_results_list_GBM, list(myBiomodModelEval.tuned))
    
  }
  
  # Rebind and save performance for different HPs
  evaluation_results_tuning_GBM <- bind_rows(evaluation_results_list_GBM)
  
  output_path <- file.path(evaluation_results_folder, "GBM_summary_tuning.csv")
  write.csv(evaluation_results_tuning_GBM, file = output_path, row.names = FALSE)
  
  # Calculate mean over all runs for each combination of HP
  mean_over_all_runs <- evaluation_results_tuning_GBM  %>% 
    group_by(n.trees, interaction.depth, n.minobsinnode, shrinkage) %>%
    summarise(mean_validation = mean(validation, na.rm = TRUE))
  
  
  GBM.tuned.n.trees <- mean_over_all_runs[which.max(mean_over_all_runs$mean_validation),]$n.trees
  GBM.tuned.interaction.depth <- mean_over_all_runs[which.max(mean_over_all_runs$mean_validation),]$interaction.depth
  GBM.tuned.shrinkage <- mean_over_all_runs[which.max(mean_over_all_runs$mean_validation),]$shrinkage
  GBM.tuned.n.minobsinnode <- mean_over_all_runs[which.max(mean_over_all_runs$mean_validation),]$n.minobsinnode
  
  GBM.tuned.TSS <- max(mean_over_all_runs$mean_validation)
  
  ### Save tuned HPs and TSS score of best performing models
  
  hp_all <- tibble::tibble(
    model = c("GLM", "GAM", "RFd", "GBM"),
    
    # TSS
    TSS = c(GLM.tuned.TSS,
            GAM.tuned.TSS,
            RFd.tuned.TSS,
            GBM.tuned.TSS),
    
    # Formeln als Text speichern
    formula = c(
      paste(deparse(GLM.tuned.formula), collapse = " "),
      paste(deparse(GAM.tuned.formula), collapse = " "),
      NA,
      NA
    ),
    
    # Interaction.level für GLM/GAM (falls vorhanden)
    interaction = c(
      GLM.tuned.interaction,
      GAM.tuned.interaction,
      NA,
      NA
    ),
    
    # RF hyperparams
    mtry = c(NA, NA, RFd.tuned.mtry, NA),
    nodesize = c(NA, NA, RFd.tuned.nodesize, NA),
    
    # GBM hyperparams
    gbm_trees = c(NA, NA, NA, GBM.tuned.n.trees),
    gbm_depth = c(NA, NA, NA, GBM.tuned.interaction.depth),
    gbm_shrinkage = c(NA, NA, NA, GBM.tuned.shrinkage),
    gbm_minobsinnode = c(NA, NA, NA, GBM.tuned.n.minobsinnode)
  )
  
  # Save performance results 
  HP_folder <- file.path(outputFolder, paste0("set_tuned_HP"))
  if (!dir.exists(HP_folder)) {
    dir.create(HP_folder, recursive = TRUE)
  }
  
  write.csv(hp_all, file.path(HP_folder,"final_HP_TSS_overview.csv"), row.names = FALSE)
  
  
  # For the final model: Monte Carlo approach 
  myCVtable_final  <- bm_CrossValidation(
    bm.format = biomod_data_final_model,
    strategy = "random",
    nb.rep = 10,
    perc = 0.7
  )
  
  
  # Model training for 10 different samples of dataset 
  
  # Set tuned HPs
  
  # GLM
  tuned_GLM_form <- bm_MakeFormula(resp.name = biomod_data_final_model@sp.name,
                                   expl.var = head(biomod_data_final_model@data.env.var),
                                   type = GLM.tuned.formula,
                                   interaction.level = GLM.tuned.interaction)
  
  final.GLM <- list()
  for (j in 1:10) {
    final.GLM[[paste0('_PA1_RUN', j)]] <- list(formula = tuned_GLM_form)
  }
  
  # GAM
  tuned_GAM_form <- bm_MakeFormula(resp.name = biomod_data_final_model@sp.name,
                                   expl.var = head(biomod_data_final_model@data.env.var),
                                   type = GAM.tuned.formula,
                                   interaction.level = GAM.tuned.interaction)
  
  final.GAM <- list()
  for (j in 1:10) {
    final.GAM[[paste0('_PA1_RUN', j)]] <- list(formula = tuned_GAM_form)
  }
  
  
  # RFd
  final.RFd <- list()
  for (j in 1:10) {
    final.RFd[[paste0('_PA1_RUN', j)]] <- list(
      formula = form,
      ntrees = 500,
      mtry = RFd.tuned.mtry,
      nodesize = RFd.tuned.nodesize
    )
  }
  
  # GBM 
  final.GBM <- list()
  for (j in 1:10) {
    final.GBM[[paste0('_PA1_RUN', j)]] <- list(
      formula = form,
      n.trees = GBM.tuned.n.trees,
      interaction.depth = GBM.tuned.interaction.depth,
      n.minobsinnode = GBM.tuned.n.minobsinnode,
      shrinkage = GBM.tuned.shrinkage
    )
  }
  
  final.user.val <- list(
    GLM.binary.stats.glm = final.GLM,
    GAM.binary.mgcv.gam = final.GAM,
    RFd.binary.randomForest.randomForest = final.RFd,
    GBM.binary.gbm.gbm = final.GBM)
  
  finalOpt <- bm_ModelingOptions(
    data.type = 'binary',
    models = c("GLM", "GAM", "RFd", "GBM"),
    strategy = "user.defined",
    user.val = final.user.val,
    user.base = "bigboss",
    bm.format = biomod_data_final_model,
    calib.lines = myCVtable_final
  )
  
  finalModelOut <- BIOMOD_Modeling(
    bm.format = biomod_data_final_model,
    modeling.id = selected_species_name,
    models = c("GLM", "GAM", "RFd", "GBM"),
    CV.strategy = 'user.defined',
    CV.user.table = myCVtable_final,
    OPT.user = finalOpt,
    var.import = 3,
    metric.eval = c('TSS'),
    nb.cpu = nb.cpu
  )
  
  # Save performance results 
  evaluation_results_folder <- file.path(outputFolder, paste0("final_model_evaluation"))
  if (!dir.exists(evaluation_results_folder)) {
    dir.create(evaluation_results_folder, recursive = TRUE)
  }
  
  # Save relative tuned results
  finalEval <- get_evaluations(finalModelOut)
  
  # Create csv
  write.csv(finalEval, 
            file = file.path(evaluation_results_folder, "final_model_tuned.csv"),
            row.names = FALSE)
  
  # Save variables importance 
  var_imp_folder <- file.path(outputFolder, paste0("variable_importance"))
  if (!dir.exists(var_imp_folder)) {
    dir.create(var_imp_folder, recursive = TRUE)
  }
  
  var_imp <- get_variables_importance(finalModelOut)
  
  write.csv(var_imp,
            file = file.path(var_imp_folder, "variable_importance_final_model.csv"),
            row.names = FALSE)
  
  
  
  # Project the models onto historic environmental conditions
  myBiomodProj_historic <- BIOMOD_Projection(
    bm.mod = finalModelOut,
    proj.name = paste0("my_species_projection_hist"),
    new.env = expl_var,
    models.chosen = 'all',
    metric.binary = "TSS",
    compress = TRUE,
    nb.cpu = nb.cpu
  )
  
  bin_hist_proj <- get_predictions(myBiomodProj_historic, metric.binary = "TSS")
  
  # Calculate area for hole study region historic projection
  cell_size_hist_proj <- cellSize((bin_hist_proj), unit="km")
  hist_proj_area <- global(cell_size_hist_proj * (bin_hist_proj == 1), "sum", na.rm =TRUE)$sum
  
  
  # Calculate area in amazon region
  
  # Cut out amazon region
  amazon_rast <- rast(amazon_mask_path)
  
  
  amazon_crop <- crop(amazon_rast, bin_hist_proj)
  amazon_ext <- extend(amazon_crop, bin_hist_proj)
  bin_hist_proj_amazon <- bin_hist_proj * (amazon_ext== 1)
  cell_size_hist_amazon_proj <- cellSize((bin_hist_proj_amazon), unit="km")
  hist_proj_amazon_area <- global(cell_size_hist_amazon_proj * (bin_hist_proj_amazon == 1), "sum", na.rm =TRUE)$sum
  
  hist_area_df <- tibble(
    name = names(bin_hist_proj),
    hist_area = hist_proj_area,
    hist_area_amazon = hist_proj_amazon_area
  ) %>%
    mutate(
      model_run = str_extract(name, "RUN\\d+") %>% str_remove("RUN") %>% as.integer(),
      algo = str_extract(name, "RFd|GBM|GLM|GAM")
    ) %>%
    select(algo, model_run, hist_area, hist_area_amazon)
  
  
  # Load MC samples dataset
  mc_df <- read.csv(mc_sample_path)
  
  
  
  # Define scenarios
  
  # SSPs
  ssps <- c("ssp245", "ssp370")
  
  # Tipping
  tipping <- c("notip", "tip")
  
  # Deforestation
  deforestation <- c("no_deforestation", "deforestation")
  
  # time periods
  periods <- c("2030_2044", "2050_2069", "2080_2099")
  
  # Store results:
  future_results_list <- list()
  
  ### Iterate through all scenarios
  for (ssp in ssps) {
    for (tip in tipping) {
      
      defor_values <- if (tip == "tip") deforestation else "no_deforestation"
      
      for (defor in defor_values) {
        for (period in periods) {
          
          # If tipping analysis is considered, apply Monte Carlo approach 
          if (tip == "tip") {
            for (i in c(1:nrow(mc_df))) {
              algo <- mc_df[i,"algo"]
              model_run <- mc_df[i,"model_run"]
              prec_sample <- mc_df[i, "prec_sample"]
              
              
              future_var_path <- file.path(selected_bioclim_dir, 
                                           paste0(selected_species_name,"_", ssp, "_", tip, "_", defor, "_", period, ".tif"))
              
              masked_future_bioclim_vars <- rast(future_var_path)
              
              # Layers to extract
              target_layers <- paste0(selected_vars_indices, "_sample=", prec_sample)
              
              # Select bioclim vars
              selected_future_bioclim_vars <- masked_future_bioclim_vars[[target_layers]]
              
              # Make names similar again
              names(selected_future_bioclim_vars) <- gsub("_sample=.*", "", names(selected_future_bioclim_vars))
              
              # Transform to raster
              future_expl_var <- as(selected_future_bioclim_vars, "SpatRaster")
              
              # Select the model for projection
              
              # Check model pattern
              model_pattern <- paste0("RUN", model_run, "_", algo)
              selected_model_name <- grep(model_pattern, finalModelOut@models.computed , value = TRUE)
              
              dup_index <- mc_df[i, "dup_index"]
              
              proj_name_future <- paste0(
                selected_species_name, "_", ssp, "_", tip, "_", defor, "_", period, "_",
                algo, "_", model_run, "_", prec_sample,
                if (dup_index > 0) paste0("_", dup_index) else ""
              )
              
              myBiomodProj_future <- BIOMOD_Projection(
                bm.mod = finalModelOut,                   
                proj.name = proj_name_future,
                new.env = future_expl_var,
                models.chosen = selected_model_name,  
                metric.binary = "TSS",
                compress = TRUE,
                nb.cpu = nb.cpu
              )
              
              # Calculate area loss for future projection
              bin_future_proj <- get_predictions(myBiomodProj_future, metric.binary = "TSS")
              
              # Full study area
              cell_size <- cellSize(bin_future_proj, unit = "km")
              
              # Select historical projection for given algorithm and model run 
              bin_hist_proj_selected <- bin_hist_proj[paste0(species_name_with_point, "_PA1_RUN", model_run, "_", algo)]
              bin_hist_proj_amazon_selected  <- bin_hist_proj_amazon[paste0(species_name_with_point, "_PA1_RUN", model_run, "_", algo)]
              
              # No dispersal (full area)
              no_dispersal_rast <- bin_future_proj * (bin_hist_proj_selected == 1)

              # Full dispersal (amazon area)
              amazon_crop <- crop(amazon_rast, bin_future_proj)
              amazon_ext <- extend(amazon_crop, bin_future_proj)
              rast_obj_amazon <- bin_future_proj * (amazon_ext == 1)
              cell_size_amazon <- cellSize(bin_hist_proj_amazon_selected, unit = "km")
              
              # No dispersal (amazon area)
              no_dispersal_rast_amazon <- rast_obj_amazon * (bin_hist_proj_amazon_selected == 1)
              
              df_fut <- tibble(
                layer = names(bin_future_proj),
                future_area_no_dispersal =
                  global(cell_size * (no_dispersal_rast == 1), "sum", na.rm = TRUE)$sum,
                future_area_full_dispersal =
                  global(cell_size * (bin_future_proj == 1), "sum", na.rm = TRUE)$sum,
                future_area_no_dispersal_amazon =
                  global(cell_size_amazon * (no_dispersal_rast_amazon == 1), "sum", na.rm = TRUE)$sum,
                future_area_full_dispersal_amazon =
                  global(cell_size_amazon * (rast_obj_amazon == 1), "sum", na.rm = TRUE)$sum
              ) %>%
                mutate(
                  model_run = model_run,
                  algo = algo,
                  prec_sample = prec_sample,
                  species_name = selected_species_name,
                  ssp = ssp,
                  tip = tip,
                  deforestation = defor,
                  time_period = period
                )
              
              future_results_list <- append(future_results_list, list(df_fut))
              
            }
          }
          else {
            future_var_path <- file.path(selected_bioclim_dir, 
                                         paste0(selected_species_name,"_", ssp, "_", tip, "_", defor, "_", period, ".tif"))
            
            masked_future_bioclim_vars <- rast(future_var_path)
            selected_future_bioclim_vars <- masked_future_bioclim_vars[[selected_vars_indices]]
            # Transform to raster
            future_expl_var <- as(selected_future_bioclim_vars, "SpatRaster")
            
            proj_name_future <- paste0(selected_species_name,"_", ssp, "_", tip, "_", defor, "_", period)
            myBiomodProj_future <- BIOMOD_Projection(
              bm.mod = finalModelOut,                   
              proj.name = proj_name_future,
              new.env = future_expl_var,
              selected.models = "all",  
              metric.binary = "TSS",
              compress = TRUE,
              nb.cpu = nb.cpu
            )
            
            # Calculate area loss for future projection
            bin_future_proj <- get_predictions(myBiomodProj_future, metric.binary = "TSS")
            
            # Full study area
            cell_size <- cellSize(bin_future_proj, unit = "km")
            
            # No dispersal (full area)
            no_dispersal_rast <- bin_future_proj * (bin_hist_proj == 1)
            
            # Full dispersal (amazon area)
            amazon_crop <- crop(amazon_rast, bin_future_proj)
            amazon_ext <- extend(amazon_crop, bin_future_proj)
            rast_obj_amazon <- bin_future_proj * (amazon_ext == 1)
            cell_size_amazon <- cellSize(bin_hist_proj_amazon, unit = "km")
            
            # No dispersal (amazon area)
            no_dispersal_rast_amazon <- rast_obj_amazon * (bin_hist_proj_amazon == 1)
            
            df_fut <- tibble(
              layer = names(bin_future_proj),
              future_area_no_dispersal =
                global(cell_size * (no_dispersal_rast == 1), "sum", na.rm = TRUE)$sum,
              future_area_full_dispersal =
                global(cell_size * (bin_future_proj == 1), "sum", na.rm = TRUE)$sum,
              future_area_no_dispersal_amazon =
                global(cell_size_amazon * (no_dispersal_rast_amazon == 1), "sum", na.rm = TRUE)$sum,
              future_area_full_dispersal_amazon =
                global(cell_size_amazon * (rast_obj_amazon == 1), "sum", na.rm = TRUE)$sum
            ) %>%
              mutate(
                model_run = str_extract(layer, "RUN\\d+") %>% str_remove("RUN") %>% as.integer(),
                algo = str_extract(layer, "RFd|GBM|GLM|GAM"),
                prec_sample = NA,
                species_name = selected_species_name,
                ssp = ssp,
                tip = tip,
                deforestation = defor,
                time_period = period
              )
            
            future_results_list <- append(future_results_list, list(df_fut))
          }
        }
      }
    }
  }
  
  
  # Combine to one df
  future_results_df <- bind_rows(future_results_list)
  
  # Merge with historic areas
  final_results <- future_results_df %>%
    left_join(hist_area_df, by = c("algo", "model_run")) %>%
    
    # Reorder columns to match the desired structure
    select(
      species_name,
      ssp,
      tip,
      deforestation,
      time_period,
      algo,
      model_run,
      prec_sample,
      hist_area,
      hist_area_amazon,
      future_area_no_dispersal,
      future_area_full_dispersal,
      future_area_no_dispersal_amazon,
      future_area_full_dispersal_amazon
    )
  
  range_results_dir <- file.path(outputFolder, "area_results")
  
  if (!dir.exists(range_results_dir)) {
    dir.create(range_results_dir, recursive = TRUE)
  }
  write.csv(final_results,
            file = file.path(range_results_dir, "area_all_MC_models.csv"),
            row.names = FALSE)
}

