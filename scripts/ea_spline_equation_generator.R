# Load the essential package
library(ithir)
library(ggplot2)  # Add ggplot2 for better plotting capabilities

# Configuration
soil_features <- c("clay", "elcosp", "phaq", "sand", "silt", "orgc")
input_file <- "D:/tierra/datasets/soil_type_splits"
output_dir <- "D:/tierra/outputs/ea_spline"
plots_dir <- file.path(output_dir, "plots")  # Directory for saving plots
equations_dir <- file.path(output_dir, "equations")  # Directory for saving equations

# Create output directories if they don't exist
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
}
if (!dir.exists(plots_dir)) {
  dir.create(plots_dir, recursive = TRUE, showWarnings = FALSE)
}
if (!dir.exists(equations_dir)) {
  dir.create(equations_dir, recursive = TRUE, showWarnings = FALSE)
}

# Get list of files to process
files <- list.files(input_file, full.names = TRUE)
if (length(files) == 0) {
  stop("No files found in input directory")
}

# Simple message about processing
cat("Starting to process", length(files), "files\n")

# Start timing
total_start_time <- Sys.time()

# Process each file sequentially with progress reporting
for (i in seq_along(files)) {
  file <- files[i]
  cat(sprintf("\nFile %d of %d: %s\n", i, length(files), basename(file)))
  file_start_time <- Sys.time()
  
  # Read data
  input_data <- read.csv(file, stringsAsFactors = FALSE)
  
  # Get the file name without extension
  file_name <- tools::file_path_sans_ext(basename(file))
  
  # Process each soil feature
  for (feature in soil_features) {
    feature_start_time <- Sys.time()
    cat(sprintf("  Processing soil feature: %s\n", feature))
    
    # Extract and prepare data
    if (!(feature %in% names(input_data))) {
      cat(sprintf("  Feature '%s' not found in the dataset. Skipping.\n", feature))
      next
    }
    
    # Create subset with only needed columns
    soil_data <- data.frame(
      id = input_data$profile_id,
      top = input_data$upper_depth,
      bottom = input_data$lower_depth,
      value = input_data[[feature]]
    )
    
    # Remove rows with NA values
    soil_data <- soil_data[!is.na(soil_data$value), ]
    
    # Skip processing if no valid data
    if (nrow(soil_data) == 0) {
      cat(sprintf("  No valid data for feature: %s. Skipping.\n", feature))
      next
    }
    
    cat(sprintf("  Number of valid observations: %d\n", nrow(soil_data)))  # Fixed missing parenthesis
    
    # Fit the equal-area spline
    spline_result <- ea_spline(
      obj = soil_data,
      var = "value",
      d = c(0, 5, 15, 30),
      lam = 0.1,  # Smoothing parameter (optional)
    )
    
    # Get harmonized data at target depths
    harmonized_data <- spline_result$harmonised
    
    # Create output file path
    output_file <- file.path(output_dir, paste0(file_name, "_", feature, "_harmonized.csv"))
    
    # Save harmonized data to CSV
    write.csv(harmonized_data, output_file, row.names = FALSE)
    
    # # Extract spline equation coefficients and save to text file
    if (!is.null(spline_result$fit)) {
      # Create equation file path
      equation_file <- file.path(equations_dir, paste0(file_name, "_", feature, "_equation.txt"))
      
      # Extract coefficients from the fitted spline
      knots <- spline_result$fit$knots
      coefs <- spline_result$fit$coefs
      
      # Format the equation details
      equation_text <- paste0("# Equal-Area Spline Equation for ", feature, " in ", file_name, "\n\n")
      equation_text <- paste0(equation_text, "## Knots (boundaries between spline segments):\n")
      equation_text <- paste0(equation_text, paste(round(knots, 4), collapse = ", "), "\n\n")
      
      equation_text <- paste0(equation_text, "## Coefficients (a, b, c, d for each segment):\n")
      for (seg in 1:nrow(coefs)) {
        equation_text <- paste0(equation_text, 
                              "Segment ", seg, ": ", 
                              "a=", round(coefs[seg, 1], 6), ", ",
                              "b=", round(coefs[seg, 2], 6), ", ",
                              "c=", round(coefs[seg, 3], 6), ", ",
                              "d=", round(coefs[seg, 4], 6), "\n")
      }
      
      equation_text <- paste0(equation_text, "\n## Equation Form:\n")
      equation_text <- paste0(equation_text, "f(x) = a + b(x-knot) + c(x-knot)^2 + d(x-knot)^3\n")
      equation_text <- paste0(equation_text, "where x is depth and knot is the left boundary of each segment\n\n")
      
      # Function to calculate the value at any depth
      equation_text <- paste0(equation_text, "## To calculate value at depth x:\n")
      equation_text <- paste0(equation_text, "1. Find which segment contains x\n")
      equation_text <- paste0(equation_text, "2. Use the corresponding knot and coefficients\n")
      equation_text <- paste0(equation_text, "3. Substitute into the equation form\n")
      
      # Write equation to text file
      writeLines(equation_text, equation_file)
      cat(sprintf("  Saved equation to: %s\n", basename(equation_file)))
    } else {
        cat(sprintf("  No spline fit available for %s, cannot extract equation.\n", feature))
        cat("  Number of observations:", nrow(soil_data), "\n")
        cat("  Depth range:", min(soil_data$top), "to", max(soil_data$bottom), "\n")
        cat("  Value range:", min(soil_data$value), "to", max(soil_data$value), "\n")
        cat("  Unique depths:", length(unique(soil_data$top)), "\n")
    }

    # Save plot to file
    plot_file <- file.path(plots_dir, paste0(file_name, "_", feature, "_spline.png"))
    png(plot_file, width = 800, height = 600)
    # Create and render plot directly
    plot_ea_spline(splineOuts=spline_result, d= t(c(0,5,15,30)), maxd=30, type=1, label=paste0("Harmonized ", feature, " for ", file_name))
    dev.off()
    cat(sprintf("  Saved plot to: %s\n", plot_file))
    
    # # Convert the 1cm interval matrix to a data frame for plotting
    # plot_data <- as.data.frame(spline_result$var.1cm)
    # # Add depth column (1 cm increments)
    # plot_data$depth <- seq_len(nrow(plot_data))
    # # Ensure the column name for the soil property is correct
    # names(plot_data)[1] <- "value"
    # # Calculate midpoints and thickness for original data (for visualization)
    # soil_data$mid <- (soil_data$top + soil_data$bottom) / 2
    # soil_data$thickness <- soil_data$bottom - soil_data$top
    # # Create color palette for bars
    # layer_colors <- hcl.colors(nrow(soil_data), "Blues")
    # # Plot with bars for original values and a line with points for the spline
    # p <- ggplot() +
    # # Bars for observed data with distinct borders
    # geom_rect(data = soil_data,
    #             aes(xmin = 0, xmax = value,
    #                 ymin = top, ymax = bottom,
    #                 fill = factor(mid)),  # Use midpoint for distinct colors
    #             alpha = 0.6,
    #             color = "black",          # Add border
    #             linewidth = 0.5) +             # Border thickness
    
    # # Line for spline-fitted data
    # geom_line(data = plot_data, 
    #             aes(x = value, y = depth),
    #             color = "red", 
    #             linewidth = 1) +
    
    # # Points for spline data at 5cm intervals
    # # geom_point(data = plot_data[seq(1, nrow(plot_data), by = 5), ],
    # #            aes(x = value, y = depth),
    # #            color = "darkred",
    # #            size = 2,
    # #            shape = 16) +
    
    # # Add points for original measurements at midpoints
    # # geom_point(data = soil_data,
    # #            aes(x = value, y = mid),
    # #            color = "blue",
    # #            size = 3,
    # #            shape = 18) +
    
    # # Layer-specific visual elements
    # scale_fill_manual(values = layer_colors) +
    # scale_y_reverse(breaks = seq(0, 30, by = 5)) +  # Improved y-axis
    
    # # Add horizontal lines at standard depths
    # geom_hline(yintercept = c(15), 
    #             linetype = "dashed", 
    #             color = "darkgrey") +
    
    # # Improved labels
    # labs(title = paste("Equal-Area Spline Fit for Soil Property", feature, " for", file_name),
    #     subtitle = "Original measurements with fitted continuous function",
    #     x = paste("Soil Property", feature, "Value"),
    #     y = "Depth (cm)",
    #     caption = "Points show original measurements; red line shows spline fit") +
    
    # # Remove fill legend and improve theme
    # guides(fill = "none") +
    # theme_minimal() +
    # theme(
    #     panel.grid.minor = element_blank(),
    #     axis.title = element_text(face = "bold"),
    #     plot.title = element_text(face = "bold"),
    #     plot.subtitle = element_text(face = "italic")
    # )

    # plot_file <- file.path(plots_dir, paste0(file_name, "_", feature, "_spline.png"))
    # ggsave(plot_file, p, width = 8, height = 6, dpi = 300)
    # # Print the plot
    # print(p)
    # cat(sprintf("  Saved simple plot to: %s\n", basename(plot_file)))
  }
  
  file_end_time <- Sys.time()
  elapsed <- round(difftime(file_end_time, file_start_time, units = "mins"), 2)
  cat(sprintf("Completed processing file %s in %.2f minutes\n", basename(file), elapsed))
}

# End timing
total_end_time <- Sys.time()
elapsed <- round(difftime(total_end_time, total_start_time, units = "mins"), 2)
cat(sprintf("\nTotal processing completed in %.2f minutes\n", elapsed))