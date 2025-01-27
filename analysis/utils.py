import datetime
import os
import numpy as np

def print_error(message):
    """
    Print an error message in red.
    """
    print(f"\033[91m{message}\033[0m")

def print_success(message):
    """
    Print a success message in green.
    """
    print(f"\033[92m{message}\033[0m")

def print_info(message):
    """
    Print an info message in yellow.
    """
    print(f"\033[93m{message}\033[0m")

def filter_by_country(code, df, country):
    """
    Filter a DataFrame by a specific country name.
    @param code - The country code.
    @param df - The DataFrame to filter.
    @param country - The name of the country to filter by.
    @return A subset of the DataFrame filtered by the specified country.
    """
    # if country is not in the dataframe, return the dataframe
    if country not in df['country_name'].values:
        print_error(f"Country not found in the dataframe:{code}")
    return df[df['country_name'] == country]

def makeOutputDir(directory, baseDir='./outputs'):
    """
    Create a new output directory based on the current date and a given directory name.
    @param directory - The name of the directory to be created.
    @return The path of the newly created output directory.
    """
    # create output directory if not exists
    date = datetime.datetime.now().strftime("%Y%m%d")
    output_dir = f'{baseDir}/{date}/{directory}'
    if not os.path.exists(output_dir):
        os.makedirs(output_dir, exist_ok=True)
    return output_dir

def sanitize_data(df, column = 'value'):
    """
    Sanitize the data by removing outliers based on z-scores and filling missing values with the mean.
    @param df - the input DataFrame containing the data
    @param column - the column to sanitize
    @return The sanitized DataFrame
    """
    # normalize data using z-score
    z_scores = np.abs((df[column] - df[column].mean()) / df[column].std())
    df = df[z_scores < 3]

    # fill missing values with the mean of the column
    df[column] = df[column].fillna(df[column].mean()).copy()

    return df
