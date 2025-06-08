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
soil_features <- c("clay", "elcosp", "phaq", "sand", "silt", "orgc")

# Define input and output paths
input_file <- "D:/tierra/outputs/unfiltered/mexico/wosis_202312_orgc_soil_features_cleaned.csv"
output_dir <- "D:/tierra/outputs/unfiltered/harmonized/mexico/orgc"

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
  
  # Create a data frame to store harmonized data
  all_harmonized <- data.frame()
  
  # Process each profile separately
  profile_ids <- unique(soil_data$id)
  cat(paste0("Processing ", length(profile_ids), " soil profiles\n"))
  
  for (pid in profile_ids) {
    # Extract data for this profile
    profile_data <- soil_data[soil_data$id == pid, ]
    
    # Skip profiles with less than 2 depth measurements
    # if (nrow(profile_data) < 2) {
    #   cat(paste0("Profile ID ", pid, " has fewer than 2 depth measurements. Skipping.\n"))
    #   next
    # }
    
    # Remove duplicate depths by averaging values
    profile_data <- aggregate(value ~ id + top + bottom, data = profile_data, mean)
    
    # Add small noise to duplicated depths (if any remain after aggregation)
    depth_counts <- table(profile_data$top)
    duplicate_depths <- as.numeric(names(depth_counts[depth_counts > 1]))
    
    if (length(duplicate_depths) > 0) {
      for (d in duplicate_depths) {
        idx <- which(profile_data$top == d)
        if (length(idx) > 1) {
          profile_data$top[idx[-1]] <- profile_data$top[idx[-1]] + seq(0.001, 0.009, length.out = length(idx) - 1)
        }
      }
    }
    
    # Try to fit the spline for this profile
    tryCatch({
      spline_result <- ea_spline(
        obj = profile_data,
        var = "value",
        d = c(0, 30)
      )
      
      # Add to the combined results
      all_harmonized <- rbind(all_harmonized, spline_result$harmonised)
    }, error = function(e) {
      cat(paste0("Error processing profile ID ", pid, ": ", e$message, "\n"))
    })
  }
  
  # Skip if no profiles were successfully processed
  if(nrow(all_harmonized) == 0) {
    cat(paste0("No profiles could be successfully processed for feature: ", feature, ". Skipping.\n"))
    return(NULL)
  }
  
  # Create output file path
  output_file <- file.path(output_dir, paste0(feature, "_harmonized.csv"))
  
  # Save harmonized data to CSV
  write.csv(all_harmonized, output_file, row.names = FALSE)
  cat(paste0("Saved harmonized data to: ", output_file, "\n"))
  
  return(all_harmonized)
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