import os
from pathlib import Path

import numpy as np
import pandas as pd

DATA_ROOT = Path(os.environ["AMAZON_DATA_DIR"])
base = DATA_ROOT / "intermediate" / "06_sdm" / "models"
output_dir = DATA_ROOT / "intermediate" / "07_postprocess_data" / "sdm_area_change"
output_dir.mkdir(parents=True, exist_ok=True)

results = []
filename = "area_all_MC_models.csv"

for species_folder in base.iterdir():
    if species_folder.is_dir():
        area_dir = species_folder / "area_results"

        if not area_dir.exists():
            print(f"No area folder for {species_folder.name}")
            continue

        file_path = area_dir / filename

        if not file_path.exists():
            print(f"Missing file for {species_folder.name}: {filename}")
            continue

        df = pd.read_csv(file_path)
        results.append(df)

area_csv = pd.concat(results, ignore_index=True)

# Calculate relative area change.
area_csv["relative_change_full_area_full_dispersal"] = (
    (area_csv["future_area_full_dispersal"] - area_csv["hist_area"])
    / area_csv["hist_area"]
    * 100
)
area_csv["relative_change_full_area_no_dispersal"] = (
    (area_csv["future_area_no_dispersal"] - area_csv["hist_area"])
    / area_csv["hist_area"]
    * 100
)
area_csv["relative_change_amazon_area_full_dispersal"] = (
    (area_csv["future_area_full_dispersal_amazon"] - area_csv["hist_area_amazon"])
    / area_csv["hist_area_amazon"]
    * 100
)
area_csv["relative_change_amazon_area_no_dispersal"] = (
    (area_csv["future_area_no_dispersal_amazon"] - area_csv["hist_area_amazon"])
    / area_csv["hist_area_amazon"]
    * 100
)

area_csv.to_csv(
    output_dir / "final_amazon_area_ETresid_updateds.csv",
    index=False,
)
