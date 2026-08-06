# 01b -- Tipping-model precipitation data preprocessing

## Folder overview

This folder converts moisture-network and tipping-model outputs into precipitation-change ensembles. These ensembles provide the climate-change-only and climate-change-plus-tipping precipitation changes used in 01c.

## Scripts

- `cluster/process_moisture_network_evap_MC.py`: production calculation for one SSP and tipping scenario.
- `cluster/submitPIK.py`: creates and submits one Slurm job for each SSP/scenario combination.
- `cluster/slurm_template.sh`: generic Slurm template used by `submitPIK.py`.

## Important calculations

For every future year and month, the script reads the original NorESM moisture network and precipitation, samples whether cells tip according to their tipping risk, removes the relevant moisture flows after accounting for residual evapotranspiration, and repeats this Monte Carlo calculation 100 times. It writes historical precipitation (`histpr`), climate-change-only percentage change (`PC_CC`), and tipping-inclusive percentage change (`PC_CCTIP`).

## Inputs

- `data/e_p_moisture_network_amazon_historical.nc`: included historical moisture-network precipitation file.
- `data/Share_DeltaET_MaxClemens/`: expected external input directory; it must contain `deltaE_amazon_network.nc`, tipping-risk maps, and original monthly network files.

## Outputs

The current script writes one NetCDF ensemble per scenario to `data/PRECIP_CHANGES/`. For the portable pipeline, stage these files under `$AMAZON_DATA_DIR/intermediate/01_b_precipitation_changes/` before running 01c.

## Tipping-model provenance

The included historical input was generated with the model used in Wunderling, N., Sakschewski, B., Rockstrom, J. et al. *Deforestation-induced drying lowers Amazon climate threshold*. **Nature** 654, 114--120 (2026). https://doi.org/10.1038/s41586-026-10456-0

The Article's code-availability statement cites the upstream model code at https://doi.org/10.6084/m9.figshare.28191128. Its interacting dynamical-systems approach is based on PyCascades (Wunderling et al., 2021, *Eur. Phys. J. Spec. Top.* 230, 3163--3176).
## Detailed input/output inventory

### Inputs

| Location | Data | Origin | Used by |
| --- | --- | --- | --- |
| `data/e_p_moisture_network_amazon_historical.nc` | Historical monthly moisture-network precipitation | Included historical tipping-model output | `process_moisture_network_evap_MC.py` |
| `data/Share_DeltaET_MaxClemens/deltaE_amazon_network.nc` | Monthly evapotranspiration change after tipping | External input listed in `Note.txt` | Production script |
| `data/Share_DeltaET_MaxClemens/<scenario>/risk_map_*.txt` | Tipping-risk maps | External input listed in `Note.txt` | Production script |
| `data/Share_DeltaET_MaxClemens/original_networks/scenario_*.nc` | Monthly moisture networks, precipitation, and evapotranspiration | External input listed in `Note.txt` | Production script |

### Outputs

| Location | Data | Produced by | Used by |
| --- | --- | --- | --- |
| `data/PRECIP_CHANGES/amazon_precip_ETresid_perc_changes_ssp_<ssp>_tipscenario_<scenario>_MC.nc` | Ensemble with `histpr`, `PC_CC`, and `PC_CCTIP` | Production script | Staged to 01c input folder |
| `$AMAZON_DATA_DIR/intermediate/01_b_precipitation_changes/` | Portable staged copy of the same ensembles | Data-staging step | 01c |