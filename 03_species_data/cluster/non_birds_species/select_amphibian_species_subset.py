import geopandas as gpd
import numpy as np
import pandas as pd

path = f"{DATA_ROOT}/raw/03_species_ranges/iucn/AMPHIBIANS/AMPHIBIANS.shp"

amphibians = gpd.read_file(path)

species_names = amphibians["sci_name"].unique()

selected_species = np.random.choice(species_names, size=50, replace=False)

amphibians_subset = amphibians[amphibians["sci_name"].isin(selected_species)]

amphibians_subset.to_file(f"{DATA_ROOT}/intermediate/03_species_data/amphibians/subset/amphibian_subset.shp")
