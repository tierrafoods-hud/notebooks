#---------------------------------------------------------------------------
# Equal Area Spline Implementation for Soil Profile Harmonization
# This script processes multiple soil features and harmonizes them to standard depths
#---------------------------------------------------------------------------

# Install required packages if not already installed
if(!require(ithir)) install.packages("ithir")

# Load necessary libraries
library(ithir)

#---------------------------------------------------------------------------
# Step 1: Setup parameters and create output directory
#---------------------------------------------------------------------------
# Define the soil features to process
soil_features <- c("clay", "phaq", "sand", "silt", "orgc")

# Define input and output paths
input_file <- "D:/tierra/datasets/Mexico_wosis_cleaned_orgc.csv"
output_dir <- "D:/tierra/outputs/harmonized/orgc"

# Create output directory if it doesn't exist
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

#---------------------------------------------------------------------------
# Step 2: Define function to process each soil feature
#---------------------------------------------------------------------------
process_soil_feature <- function(feature, input_data) {
  cat(paste0("\nProcessing soil feature: ", feature, "\n"))
  
  # Extract data for the current feature
  soil_data <- data.frame(
    id = input_data$profile_id,
    top = input_data$upper_depth,
    bottom = input_data$lower_depth,
    value = input_data[[feature]]
  )
  
  # Remove rows with NA values
  soil_data <- soil_data[!is.na(soil_data$value), ]
  
  # Skip processing if no valid data
  if(nrow(soil_data) == 0) {
    cat(paste0("No valid data for feature: ", feature, ". Skipping.\n"))
    return(NULL)
  }
  
  cat(paste0("Number of valid observations: ", nrow(soil_data), "\n"))
  
  # Fit the equal-area spline
  spline_result <- ea_spline(
    obj = soil_data,
    var = "value",
    d = c(0, 5, 15, 30)
  )
  
  # Get harmonized data at target depths
  harmonized_data <- spline_result$harmonised
  
  # Create output file path
  output_file <- file.path(output_dir, paste0(feature, "_harmonized.csv"))
  
  # Save harmonized data to CSV
  write.csv(harmonized_data, output_file, row.names = FALSE)
  cat(paste0("Saved harmonized data to: ", output_file, "\n"))
  
  return(harmonized_data)
}

#---------------------------------------------------------------------------
# Step 3: Load input data and process each feature
#---------------------------------------------------------------------------
# Load the dataset
cat("Loading soil dataset...\n")
input_data <- read.csv(input_file)
cat(paste0("Dataset loaded with ", nrow(input_data), " records\n"))

# Process each soil feature
results <- list()
for(feature in soil_features) {
  if(feature %in% colnames(input_data)) {
    results[[feature]] <- process_soil_feature(feature, input_data)
  } else {
    cat(paste0("Feature '", feature, "' not found in the dataset. Skipping.\n"))
  }
}

cat("\nProcessing complete. Harmonized data saved to:", output_dir, "\n")