library(dplyr)

# Monte carlo space
algos <- c("RFd", "GBM", "GLM", "GAM")

model_runs <- c(1:10)

prec_samples <- c(0:99) 

# Create random combinations of algo, model_run, prec_samples
create_mc_sample <- function () {
  list(
    algo = sample(algos, 1),
    model_run = sample(model_runs, 1),
    prec_sample = sample(prec_samples, 1)
  )
}

# Create 100 samples
create_mc_samples <- replicate(100, create_mc_sample(), simplify = FALSE)

# Create a dataframe
mc_df <- do.call(rbind, lapply(create_mc_samples, as.data.frame))

# Add duplicate index column
mc_df$dup_index <- ave(
  seq_len(nrow(mc_df)) - 1, 
  mc_df$algo, mc_df$model_run, mc_df$prec_sample, 
  FUN = function(x) seq_along(x) - 1
)

print(mc_df)

print(mc_df %>% 
  count(algo))

# Save MC sample
DATA_ROOT <- Sys.getenv("AMAZON_DATA_DIR")
if (DATA_ROOT == "") stop("Set AMAZON_DATA_DIR before running this script.")
save_dir <- file.path(DATA_ROOT, "intermediate", "06_sdm", "mc_samples")
dir.create(save_dir, recursive = TRUE, showWarnings = FALSE)
save_path <- file.path(save_dir, "MC_sample.csv")

write.csv(mc_df, 
          file = save_path,
          row.names = FALSE)
