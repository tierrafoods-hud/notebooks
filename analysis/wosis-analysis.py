"""
Author: Gulger Mallik (g.mallik2@hud.ac.uk)
Date: 16/12/2024
Company: Tierra Foods & University of Huddersfield

Purpose:
This script processes data from the WOSIS dataset for a specific country. It reads observations from a file, 
filters them based on country and depth criteria, merges them into a master dataframe, and then saves the merged data to a CSV file.

Usage:
python wosis-analysis.py

"""

import pandas as pd
import utils
import numpy as np
import gc  # for garbage collection

# suppress warnings
import warnings
warnings.filterwarnings("ignore")

gc.collect()

# country name
country_name = input("Please enter the country name: ")

# base path
base_path = './data/WoSIS_2023_December/'

# Load observation dataset using pandas
observations = pd.read_csv(f'{base_path}wosis_202312_observations.tsv', sep='\t')

# Column codes
codes = ["bdfiad", "bdfiod", "bdwsod", "cecph7", "cecph8", "cfvo", "clay", "ecec", "elco50", "nitkjd", "orgc", 
         "orgm", "phaq", "phetm3", "sand", "silt", "tceq", "totc", "wv0010", "wv0033", "wv1500"]

# Select important columns
valid_columns = ['date', 'longitude', 'latitude', 'upper_depth', 'lower_depth', 'country_name', 'region', 'continent', 'value_avg']

# Make output directory
outputPath = utils.makeOutputDir(f'{country_name}_wosis')

##### Do not change anything below this line #####
# Add dtype definitions for memory optimization
dtype_dict = {
    'date': 'str',
    'longitude': 'float32',
    'latitude': 'float32',
    'country_name': 'category',
    'region': 'category',
    'continent': 'category',
    'upper_depth': 'float32',
    'lower_depth': 'float32',
    'value_avg': 'float32'
}

# Initialize master_df as None instead of empty DataFrame
master_df = None

for code in codes:
    try:
        # Initialize observation counter
        total_observations = 0
        
        # Read data in chunks
        chunk_size = 100000
        chunks = pd.read_csv(f'{base_path}/wosis_202312_{code}.tsv',
                           sep='\t',
                           dtype=dtype_dict,
                           chunksize=chunk_size)
        
        # Process each chunk
        filtered_chunks = []
        for chunk in chunks:
            # Filter by country
            chunk = utils.filter_by_country(code, chunk, country_name)
            
            if not chunk.empty:
                # Process data
                chunk = chunk[valid_columns].copy()
                chunk = chunk.rename(columns={'value_avg': 'value'})
                
                # Apply depth filters
                chunk = chunk[(chunk['upper_depth'] <= 30) & (chunk['lower_depth'] <= 30)]
                chunk = chunk.rename(columns={'value': f"{code}"})
                
                filtered_chunks.append(chunk)
                
                # Update observation counter
                total_observations += len(chunk)
            
            # Clean up memory
            del chunk
            gc.collect()
        
        # Combine filtered chunks
        if filtered_chunks:
            df = pd.concat(filtered_chunks, ignore_index=True)

            # merge columns list
            merge_columns = ['date', 'longitude', 'latitude', 'upper_depth', 'lower_depth', 'country_name', 'region', 'continent']
            
            # Merge with master_df
            if master_df is None:
                master_df = df
            else:
                master_df = master_df.merge(df, on=merge_columns, how='outer')

            # Log the number of observations
            utils.print_info(f'{code}: {total_observations} observations')
        
        # Clean up memory
        del df, filtered_chunks
        gc.collect()
        
    except Exception as e:
        utils.print_error(f"Error processing {code}: {str(e)}")
        continue

# Log total rows in master_df
if master_df is not None:
    utils.print_info(f'Total rows in master_df: {len(master_df)}')

# Save to CSV in chunks
if master_df is not None:
    chunk_size = 50000
    for i, chunk in enumerate(np.array_split(master_df, len(master_df) // chunk_size + 1)):
        mode = 'w' if i == 0 else 'a'
        header = i == 0
        chunk.to_csv(f'{outputPath}/{country_name}_wosis_merged.csv',
                    index=False,
                    mode=mode,
                    header=header)
    utils.print_success(f'{country_name} WOSIS merged complete length: {len(master_df)}')