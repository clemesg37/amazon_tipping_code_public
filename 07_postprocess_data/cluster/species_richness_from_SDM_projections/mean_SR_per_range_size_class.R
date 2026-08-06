DATA_ROOT <- Sys.getenv("AMAZON_DATA_DIR")
if (DATA_ROOT == "") {
  stop("Set AMAZON_DATA_DIR before running this script.")
}

library(terra)
library(stringr)

results_dir <- file.path(DATA_ROOT, "intermediate", "07_postprocess_data", "species_richness_from_SDM_projections", "results_by_class")

terraOptions(progress = 1, memfrac = 0.8)

# list all tif files
files_all <- list.files(results_dir, pattern = "\\.tif$", full.names = TRUE)

# extract range size class from filename
classes <- unique(str_extract(basename(files_all),
                              "(?<=historic_richness_)[^_]+"))

print(classes)

for (cl in classes) {

  cat("Processing class:", cl, "\n")

  files <- files_all[str_detect(files_all,
                                paste0("historic_richness_", cl, "_MC_"))]

  cat("Found", length(files), "files\n")

  if (length(files) == 0) next

  r <- rast(files)

  mean_r <- mean(r)

  writeRaster(
    mean_r,
    file.path(results_dir,
              paste0("historic_richness_", cl, "_MEAN.tif")),
    overwrite = TRUE
  )

  cat("Finished class:", cl, "\n\n")
}

cat("All done.\n")