#---------------------------------------------------------------------------
# Equal Area Spline Implementation for Soil Profile Harmonization
# This script demonstrates the use of the ea_spline function from the ithir package
# for harmonizing soil profile data to standard depth intervals.
#---------------------------------------------------------------------------

# Install required packages if not already installed
if(!require(ithir)) install.packages("ithir")
if(!require(ggplot2)) install.packages("ggplot2")

# Load necessary libraries
library(ithir)
library(ggplot2)

#---------------------------------------------------------------------------
# Step 1: Create dummy soil profile data in correct format
#---------------------------------------------------------------------------
# The data must have columns for profile id, top depth, bottom depth, and soil property value

# Load dataset from path
soil_property <- "orgc"  # Example soil property
soil_data <- read.csv("D:/tierra/outputs/Mexico_wosis_multi_depth_clean_20250414_143053.csv")
soil_data <- data.frame(
  id = soil_data$profile_id,
  top = soil_data$upper_depth,
  bottom = soil_data$lower_depth,
  value = soil_data$orgc
)

# Dummy data
# soil_data <- data.frame(
#   id = rep("Profile_1", 5),
#   top = c(0, 8, 12, 18, 22),
#   bottom = c(8, 12, 18, 22, 30),
#   value = c(1.5, 2.0, 1.8, 2.5, 2.2)
# )

# Display input data
print("Original soil profile data:")
print(soil_data)

#---------------------------------------------------------------------------
# Step 2: Fit the equal-area spline
#---------------------------------------------------------------------------
# Define the standard depth intervals for harmonization (0-15 and 15-30 cm)
spline_result <- ea_spline(
  obj = soil_data,
  var = "value",  # Name of the soil property column
  d = c(0, 15, 30)  # Target depths for harmonization
)

#---------------------------------------------------------------------------
# Step 3: View harmonized data at target depths
#---------------------------------------------------------------------------
harmonized_data <- spline_result$harmonised
print("Harmonized data at target depths:")
print(harmonized_data)

#---------------------------------------------------------------------------
# Step 4: Prepare data for visualization
#---------------------------------------------------------------------------
# Convert the 1cm interval matrix to a data frame for plotting
plot_data <- as.data.frame(spline_result$var.1cm)

# Add depth column (1 cm increments)
plot_data$depth <- seq_len(nrow(plot_data))

# Ensure the column name for the soil property is correct
names(plot_data)[1] <- "value"

# Calculate midpoints and thickness for original data (for visualization)
soil_data$mid <- (soil_data$top + soil_data$bottom) / 2
soil_data$thickness <- soil_data$bottom - soil_data$top

#---------------------------------------------------------------------------
# Step 5: Enhanced visualization of spline fit and original data
#---------------------------------------------------------------------------
# Create color palette for bars
layer_colors <- hcl.colors(nrow(soil_data), "Blues")

# Plot with bars for original values and a line with points for the spline
p <- ggplot() +
  # Bars for observed data with distinct borders
  geom_rect(data = soil_data,
            aes(xmin = 0, xmax = value,
                ymin = top, ymax = bottom,
                fill = factor(mid)),  # Use midpoint for distinct colors
            alpha = 0.6,
            color = "black",          # Add border
            size = 0.5) +             # Border thickness
  
  # Line for spline-fitted data
  geom_line(data = plot_data, 
            aes(x = value, y = depth),
            color = "red", 
            size = 1) +
  
  # Points for spline data at 5cm intervals
  # geom_point(data = plot_data[seq(1, nrow(plot_data), by = 5), ],
  #            aes(x = value, y = depth),
  #            color = "darkred",
  #            size = 2,
  #            shape = 16) +
  
  # Add points for original measurements at midpoints
  # geom_point(data = soil_data,
  #            aes(x = value, y = mid),
  #            color = "blue",
  #            size = 3,
  #            shape = 18) +
  
  # Layer-specific visual elements
  scale_fill_manual(values = layer_colors) +
  scale_y_reverse(breaks = seq(0, 30, by = 5)) +  # Improved y-axis
  
  # Add horizontal lines at standard depths
  geom_hline(yintercept = c(15), 
             linetype = "dashed", 
             color = "darkgrey") +
  
  # Improved labels
  labs(title = paste("Equal-Area Spline Fit for Soil Property", soil_property, "Harmonization"),
       subtitle = "Original measurements with fitted continuous function",
       x = paste("Soil Property", soil_property, "Value"),
       y = "Depth (cm)",
       caption = "Points show original measurements; red line shows spline fit") +
  
  # Remove fill legend and improve theme
  guides(fill = "none") +
  theme_minimal() +
  theme(
    panel.grid.minor = element_blank(),
    axis.title = element_text(face = "bold"),
    plot.title = element_text(face = "bold"),
    plot.subtitle = element_text(face = "italic")
  )

# Print the plot
print(p)

# Save the plot (optional)
# ggsave("soil_ea_spline_visualization.png", p, width = 8, height = 6, dpi = 300)

#---------------------------------------------------------------------------
# Note: The ea_spline function harmonizes irregularly sampled soil profile data
# to standard depths using the equal-area smoothing spline approach developed by
# Bishop et al. (1999) and implemented for digital soil mapping by Malone et al. (2009).
#---------------------------------------------------------------------------