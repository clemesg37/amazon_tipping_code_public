import geopandas as gpd
import numpy as np
import os

DATA_ROOT = os.environ['AMAZON_DATA_DIR']

bird_data = gpd.read_file(f"{DATA_ROOT}/intermediate/03_species_data/birds/BOTW_2024_2.gpkg")

bird_data = bird_data[bird_data["presence"].isin([1,2,3])]
bird_data = bird_data[bird_data["origin"].isin([1,2])]
bird_data = bird_data[bird_data["seasonal"].isin([1,2,3])]

# First rough check
america_bbox = {
    "minx": -170,
    "maxx": -30,
    "miny": -60,
    "maxy": 72
}

bird_data = bird_data[
    (bird_data.geometry.bounds.minx <= america_bbox["maxx"]) &
    (bird_data.geometry.bounds.maxx >= america_bbox["minx"]) &
    (bird_data.geometry.bounds.miny <= america_bbox["maxy"]) &
    (bird_data.geometry.bounds.maxy >= america_bbox["miny"])
]

print("Number of species in America (rough filter):", len(bird_data["sci_name"].unique()))


## resident birds

# folder to save results
resident_save_dir = f"{DATA_ROOT}/intermediate/03_species_data/birds/resident"
os.makedirs(resident_save_dir, exist_ok = True)
resident_birds = bird_data[bird_data["seasonal"] == 1]
resident_birds_names = resident_birds["sci_name"].unique()
split_resident_birds_names = np.array_split(resident_birds_names, 50) 


for i, species_subset in enumerate(split_resident_birds_names, start=1):
    # Select species
    subset_df = resident_birds[resident_birds["sci_name"].isin(species_subset)]

    # Save 
    subset_df.to_file(os.path.join(resident_save_dir, f"resident_birds_part_{i}.gpkg"), driver="GPKG")

    print(f"Resident part {i}: {len(subset_df['sci_name'].unique())} species, {len(subset_df)} rows saved")

## breeding birds

# folder to save results
breeding_save_dir = f"{DATA_ROOT}/intermediate/03_species_data/birds/breeding"
os.makedirs(breeding_save_dir, exist_ok = True)
breeding_birds = bird_data[bird_data["seasonal"] == 2]
breeding_birds_names = breeding_birds["sci_name"].unique()
split_breeding_birds_names = np.array_split(breeding_birds_names, 15) 


for i, species_subset in enumerate(split_breeding_birds_names, start=1):
    # Select species
    subset_df = breeding_birds[breeding_birds["sci_name"].isin(species_subset)]

    # Save 
    subset_df.to_file(os.path.join(breeding_save_dir, f"breeding_birds_part_{i}.gpkg"), driver="GPKG")
    print(f"Breeding part {i}: {len(subset_df['sci_name'].unique())} species, {len(subset_df)} rows saved.")

## non breeding birds 

# folder to save results
non_breeding_save_dir = f"{DATA_ROOT}/intermediate/03_species_data/birds/non_breeding"
os.makedirs(non_breeding_save_dir, exist_ok = True)
non_breeding_birds = bird_data[bird_data["seasonal"] == 3]
non_breeding_birds_names = non_breeding_birds["sci_name"].unique()
split_non_breeding_birds_names = np.array_split(non_breeding_birds_names, 15) 


for i, species_subset in enumerate(split_non_breeding_birds_names, start=1):
    # Select species
    subset_df = non_breeding_birds[non_breeding_birds["sci_name"].isin(species_subset)]

    # Save 
    subset_df.to_file(os.path.join(non_breeding_save_dir, f"non_breeding_birds_part_{i}.gpkg"), driver="GPKG")
    print(f"Non-breeding part {i}: {len(subset_df['sci_name'].unique())} species, {len(subset_df)} rows saved.")