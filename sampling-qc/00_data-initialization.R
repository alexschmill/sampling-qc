# Load data
site_coords <- read_csv("~/Desktop/IOF/STAT545/PartB/sampling_qc_app/data/site_coords.csv")
metadata_raw <- read_csv("~/Desktop/IOF/STAT545/PartB/sampling_qc_app/data/cnfasar_metadata.csv")

# Load required packages
library(dplyr)
library(lubridate)
library(tidyr)

# Original raw metadata table with consistent month format
metadata_raw <- metadata %>%
  mutate(date = ymd(as.character(date)),  # Convert date to Date format
         month = month(date, label = TRUE, abbr = TRUE))  # Add month column with abbreviated names

# Filter out controls and prepare cleaned metadata dataset
metadata <- metadata_raw %>%
  filter(sample == "Sample") %>%  # Keep only "Sample" entries
  group_by(site_id, month, depth) %>%
  summarize(
    num_replicates = n(),  # Count the number of true sample replicates
    .groups = 'drop'
  ) %>%
  pivot_wider(names_from = depth, values_from = num_replicates, values_fill = 0) %>%
  rename(replicates_10m = `10`, replicates_100m = `100`)

# Merge with site_coords to include latitude and longitude
sample_data <- metadata %>%
  left_join(site_coords, by = "site_id") %>%
  mutate(lon = as.numeric(lon), lat = as.numeric(lat))  # Ensure lon and lat are numeric
