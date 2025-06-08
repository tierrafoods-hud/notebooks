import seaborn as sns
import unicodedata
import re
import matplotlib.pyplot as plt

# example helper module
def greet(name):
    return f"Hello, {name}!"


def plot_missing_values(output_dir, df):
    """
    Plot a heatmap to visualize missing values in a DataFrame and save the plot as an image.
    @param output_dir - The directory where the output image will be saved.
    @param df - The DataFrame containing the data with missing values.
    @return None
    """
    # sns plot missing values
    sns.heatmap(df.isnull(), cbar=False, cmap='viridis')
    plt.title("Missing values in the dataset")
    # save the plot
    plt.savefig(f"{output_dir}/missing_values.png", dpi=300, bbox_inches='tight')
    plt.show()


def preprocess_data(df, target, drop_columns=None, t=0.7):
    """
    Preprocess the input DataFrame by dropping specified columns, handling missing values, and duplicates.
    @param df - The input DataFrame to be preprocessed.
    @param target - The target column for the model.
    @param drop_columns - List of columns to be dropped from the DataFrame. Default is None.
    @param t - Threshold percentage for dropping columns with missing values. Default is 0.7.
    @return The preprocessed DataFrame.
    """
    # drop unnecessary columns if exists
    if drop_columns is not None:
        df.drop(columns=drop_columns, inplace=True, errors='ignore')
    
    # drop missing values in target column
    df.dropna(subset=[target], inplace=True)

    print(f"Data shape after dropping target missing values: {df.shape}")
    
    # threshold of missing values
    threshold = t * len(df)
    # drop columns with more than 70% missing values
    cols_to_drop = [col for col in df.columns if df[col].isna().sum() > threshold and col != target]
    df.drop(columns=cols_to_drop, inplace=True)

    print(f"Data shape after dropping columns: {df.shape}")

    # drop duplicates
    df.drop_duplicates(inplace=True)

    print(f"Data shape after dropping duplicates: {df.shape}")

    # drop any rows with missing values
    df.dropna(inplace=True)

    # reset index
    df.reset_index(drop=True, inplace=True)

    return df


def calculate_stocks(df, target):
    """
    Calculate the stock values based on the given dataframe and target column.
    @param df - The dataframe containing the data
    @param target - The target column for which stocks need to be calculated
    @return The dataframe with an additional column for stock values
    """

    if df['depth_category'].isnull().all():
        raise ValueError("The 'depth_category' column is missing or contains only NaN values.")

    # derive the depth difference from the depth_category
    # depth_category is in cm
    depth_mapping = {
        '0_5': 5,
        '5_15': 10,
        '15_30': 15,
        '30_60': 30,
        '60_100': 40,
        '100_200': 100
    }
    
    # Create a copy to avoid modifying the original dataframe
    df = df.copy()
    
    # Calculate bulk density using Drew (1973) pedotransfer function
    # First convert organic carbon to organic matter (OM = SOC * 1.724)
    if 'orgc' in df.columns:
        om = df['orgc'] * 1.724
        # Drew (1973) equation: BD = 1.62 - 0.06 * OM
        bulk_density = 1.62 - 0.06 * (om/10)  # divide by 10 to convert g/kg to %
    else:
        # Use average bulk density if organic carbon data is not available
        bulk_density = 1.3
    
    # Calculate the correction factor for rock fragments (cfr)
    # cfr is in percentage, divide by 100 to get fraction
    rock_correction = 1 - (df['cfr'] / 100)
    
    # Calculate stocks in tons/ha
    # Stock = concentration * bulk_density * depth * (1 - rock_fraction) * 0.1
    # 0.1 is the conversion factor from g/kg to tons/ha
    depth = df['depth_category'].map(depth_mapping)  # map depth_category to depth in cm
    stocks = df[target] * bulk_density * depth * rock_correction * 0.1
    
    # Add calculated columns to dataframe
    # df['bulk_density'] = bulk_density
    df[f'{target}_stock'] = stocks
    
    return df

# plot the distribution of the target variable
def plot_column_distribution(df, col_name):
    plt.figure(figsize=(10, 6))
    sns.histplot(df[col_name], bins=30, kde=True)
    plt.title(f"Distribution of {col_name}")
    plt.xlabel(col_name)
    plt.ylabel("Frequency")
    plt.grid()
    plt.show()


def format_filename(name):
    """
    Format a given filename by normalizing Unicode characters, removing or replacing invalid characters.
    @param name - The filename to be formatted
    @return The formatted filename
    """
    
    # Normalize unicode characters
    normalized = unicodedata.normalize('NFKD', str(name))
    # Remove non-ASCII characters
    ascii_text = normalized.encode('ASCII', 'ignore').decode()
    # Remove brackets and their contents
    no_brackets = re.sub(r'[\(\[\{].*?[\)\]\}]', '', ascii_text)
    # Replace any remaining invalid characters with underscore
    clean_name = re.sub(r'[^\w\-\.]', '_', no_brackets)
    # Convert to lowercase and remove multiple underscores
    return re.sub(r'_+', '_', clean_name.lower()).strip('_')