import sys
import os
import geopandas as gpd
import numpy as np
import rioxarray as rxr
from rasterio import features
from shapely.geometry import shape
from shapely.ops import unary_union
from pyproj import CRS
import matplotlib.pyplot as plt

species_type = sys.argv[1]
#species_type = "amphibian"
part = sys.argv[2]
#part = "1"

DATA_ROOT = os.environ['AMAZON_DATA_DIR']

# Select and preprocess 
species_data = gpd.read_file(f"{DATA_ROOT}/intermediate/03_species_data/{species_type}/{species_type}_part_{part}.gpkg")
species_data["geometry"] = species_data.geometry.simplify(
    tolerance=0.05,          
    preserve_topology=True
)
species_data = species_data.drop(columns=['id_no', 'presence', 'origin', 'seasonal', 'compiler',
       'yrcompiled', 'citation', 'subspecies', 'subpop', 'source', 'island',
       'tax_comm', 'dist_comm', 'generalisd', 'legend', 'kingdom', 'phylum',
       'class', 'order_', 'family', 'genus', 'category', 'marine',
       'terrestial', 'freshwater', 'SHAPE_Leng', 'SHAPE_Area'])

species_data["geometry"] = species_data.geometry.make_valid()
species_data = species_data.dissolve(by="sci_name").reset_index()

### Load Amazon basin mask
tif_path = f"{DATA_ROOT}/intermediate/01_c_noresm2/amazon_mask/amazon_mask.tif"

mask = rxr.open_rasterio(tif_path).squeeze()
mask_bool = (mask.values == 1).astype("uint8")
transform = mask.rio.transform()
crs = mask.rio.crs
shapes_gen = features.shapes(mask_bool, transform=transform)

amazon_polygons = [
    shape(geom)
    for geom, value in shapes_gen
    if value == 1
]

amazon_region = unary_union(amazon_polygons)

# Simplify once (safe for area ratios, big speedup)
amazon_region = amazon_region.simplify(0.05)

amazon_gdf = gpd.GeoDataFrame(
    geometry=[amazon_region],
    crs=crs
).to_crs("EPSG:4326")

amazon_geom = amazon_gdf.geometry.iloc[0]

# List of species
species_data_names = species_data["sci_name"].unique()

# Dataframe of selected species
results = []

for idx, row in species_data.iterrows():
    species_geom = row.geometry

    if species_geom.is_empty:
        continue

    if not species_geom.intersects(amazon_geom):
        print(f"{row['sci_name']}: ratio = 0.000")
        continue

    # Centroid in lon/lat
    centroid = species_geom.centroid
    lon0, lat0 = centroid.x, centroid.y

    # Local Lambert Azimuthal Equal Area projection
    laea_crs = CRS.from_proj4(
        f"+proj=laea +lat_0={lat0} +lon_0={lon0} "
        "+x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"
    )

    # Reproject species & Amazon
    species_eq = gpd.GeoSeries(
        [species_geom], crs="EPSG:4326"
    ).to_crs(laea_crs).make_valid().iloc[0]

    amazon_eq = gpd.GeoSeries(
        [amazon_geom], crs="EPSG:4326"
    ).to_crs(laea_crs).make_valid().iloc[0]

    species_area = species_eq.area
    if species_area == 0:
        continue

    intersection_area = species_eq.intersection(amazon_eq).area
    ratio = intersection_area / species_area

    print(f"{row['sci_name']}: ratio = {ratio:.3f}")

    if ratio > 0.3:
        results.append({
            "sci_name": row["sci_name"],
            "ratio": ratio,
            "area": species_area / 1e6,   
            "geometry": species_geom      
        })

results_gdf = gpd.GeoDataFrame(results, geometry="geometry", crs=species_data.crs)
print(results_gdf.head())

# Save list of species for modeling
save_folder = f"{DATA_ROOT}/intermediate/03_species_data/{species_type}/species_for_modelling/"
os.makedirs(save_folder, exist_ok=True)
save_path = os.path.join(save_folder, f"filtered_species_{part}.gpkg")
results_gdf.to_file(save_path, driver="GPKG")
print(f"Results saved under {save_path}")