# Local SDM area-change table

`final_amazon_area_ETresid_updateds.csv` is the large all-species table created by `07_postprocess_data/cluster/sdm_area_change/create_full_dataset_area_change.py`. It is used by the local Figure 3 notebook.

## Release and setup

The CSV is large (about 700 MB) and is distributed in the accompanying data ZIP archive rather than as a normal code file. Download the archive supplied with the code release and extract:

`final_amazon_area_ETresid_updateds.csv`

into this directory, so that the expected local path is:

`07_postprocess_data/local/sdm_area_change/final_amazon_area_ETresid_updateds.csv`

Do not change the filename: `08_figures/main_figures/figure_3/plot_fig_3_local.ipynb` reads this exact file.
