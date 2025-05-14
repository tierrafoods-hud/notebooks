import geopandas as gpd
import pandas as pd
import os

target = 'tceq'
base_path = f"D:/tierra/outputs/unfiltered/harmonized/"
soil_features_df_path = f"{base_path}Mexico_standardized_cleaned_{target}.csv"

# check if the file already exists
if not os.path.exists(soil_features_df_path):
    # load the dataset
    df = pd.read_csv(f"{base_path}Mexico_standardized_{target}.csv")
    print(f"Shape of the original dataset: {df.shape}")

    # set upper_depth and lower_depth as integers
    # df['upper_depth'] = df['upper_depth'].astype(int)
    # df['lower_depth'] = df['lower_depth'].astype(int)

    # convert to geodataframe
    gdf = gpd.GeoDataFrame(df, crs="epsg:4326", geometry=gpd.points_from_xy(df['longitude'], df['latitude']))

    print("Data converted to GeoDataFrame")
    print(gdf.head())

    # add soil type to the dataset
    soil_type_df = gpd.read_file("D:/tierra/data/soil/soiltype.geojson")
    soil_type_df = soil_type_df[['geometry', 'DESCRIPCIO']]
    soil_type_df = gpd.GeoDataFrame(soil_type_df, geometry='geometry')

    print("Soil type data loaded")
    print(soil_type_df.head())

    # merge with mexico dataset
    mex_gdf = gpd.sjoin(gdf, soil_type_df, how='left', predicate='within')

    # drop columns and reset index
    mex_gdf.drop(columns=['index_right'], errors='ignore', inplace=True)

    # rename column
    mex_gdf.rename(columns={'DESCRIPCIO': 'soil_type'}, inplace=True)

    slope_df = gpd.read_file("D:/tierra/data/soil/slope.geojson")
    slope_df = slope_df[['geometry', 'slopemean']]
    slope_df = gpd.GeoDataFrame(slope_df, geometry='geometry')

    print("Slope data loaded")
    print(slope_df.head())

    # merge with mexico dataset
    mex_gdf = gpd.sjoin(mex_gdf, slope_df, how='left', predicate='within')

    # drop columns
    mex_gdf.drop(columns=['index_right'], inplace=True, errors='ignore')

    # Load and prepare bedrock data
    bedrock_df = gpd.read_file("D:/tierra/data/soil/bedrock.geojson")
    bedrock_df = bedrock_df[['geometry', 'layer']]

    # Convert both dataframes to a projected CRS (UTM Zone appropriate for Mexico)
    bedrock_df = bedrock_df.to_crs("EPSG:32614")  # UTM Zone 14N (Central Mexico)
    mex_gdf = mex_gdf.to_crs("EPSG:32614")

    # Perform spatial join with nearest neighbor
    mex_gdf = gpd.sjoin_nearest(mex_gdf, bedrock_df, how='left')
    # mex_gdf = gpd.sjoin(mex_gdf, bedrock_df, how='left', predicate='within')

    # Drop unnecessary columns and convert back to WGS84
    mex_gdf = mex_gdf.drop(columns=['index_right']).to_crs("EPSG:4326")

    # rename the bedrock layer column
    mex_gdf.rename(columns={'layer': 'bedrock'}, inplace=True)

    print("Bedrock data loaded and merged")
    print(mex_gdf.head())

    # save the dataset generated so far
    mex_gdf.to_csv(soil_features_df_path, sep=",", index=False)
    print(f"Shape of the final dataset: {mex_gdf.shape}")

    # drop duplicate values
    mex_gdf.drop_duplicates(inplace=True)
    print(f"Shape of the final dataset after dropping duplicates: {mex_gdf.shape}")
else:
    mex_gdf = gpd.read_file(soil_features_df_path)
    print(f"Shape of the final dataset: {mex_gdf.shape}")