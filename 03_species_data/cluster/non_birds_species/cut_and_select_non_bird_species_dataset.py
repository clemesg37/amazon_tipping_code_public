import geopandas as gpd
import numpy as np
import os

DATA_ROOT = os.environ['AMAZON_DATA_DIR']

# list of all species
species_types = ["amphibians", "mammals", "reptiles_part1", "reptiles_part2"]
#species_types = ["reptiles_part2"]

# bounding box for america
america_bbox = {
    "minx": -170,
    "maxx": -30,
    "miny": -60,
    "maxy": 72
}

species_folder_map = {
    "reptiles_part1": "REPTILES",
    "reptiles_part2": "REPTILES",
    "amphibians": "AMPHIBIANS",
    "mammals": "MAMMALS"
}

for species in species_types:
    print(f"\n--- Processing {species} ---")

    species_upper = species.upper()
    folder = species_folder_map.get(species, species_upper)  
    species_file = f"{DATA_ROOT}/raw/03_species_ranges/iucn/{folder}/{species_upper}.shp"

    species_data = gpd.read_file(species_file)

    species_data = species_data[species_data["presence"].isin([1,2,3])]
    species_data = species_data[species_data["origin"].isin([1,2])]
    species_data = species_data[species_data["seasonal"].isin([1,2,3])]

    # Rough filter for america
    species_data = species_data[
        (species_data.geometry.bounds.minx <= america_bbox["maxx"]) &
        (species_data.geometry.bounds.maxx >= america_bbox["minx"]) &
        (species_data.geometry.bounds.miny <= america_bbox["maxy"]) &
        (species_data.geometry.bounds.maxy >= america_bbox["miny"])
    ]

    n_species = len(species_data["sci_name"].unique())
    n_splits = round(n_species / 75)
    print(f"Number of species in America (rough filter): {n_species}")
    print(f"Number of splits: {n_splits}")

    # save
    species_save_dir = f"{DATA_ROOT}/intermediate/03_species_data/{species}/"
    os.makedirs(species_save_dir, exist_ok=True)
    species_names = species_data["sci_name"].unique()
    split_species_names = np.array_split(species_names, n_splits)

    for i, species_subset in enumerate(split_species_names, start=1):
        subset_df = species_data[species_data["sci_name"].isin(species_subset)]
        outfile = os.path.join(species_save_dir, f"{species}_part_{i}.gpkg")
        subset_df.to_file(outfile, driver="GPKG")
        print(f"{species} part {i}: {len(subset_df['sci_name'].unique())} species, {len(subset_df)} rows saved.")
