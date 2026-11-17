# data/

`landing/` holds EMI CSVs downloaded on this machine. Contents are gitignored.

| Local folder | Volume path |
| --- | --- |
| `landing/final-energy-prices/` | `/Volumes/nz_energy/bronze/landing/final-energy-prices` |
| `landing/network-supply-points/` | `/Volumes/nz_energy/bronze/landing/network-supply-points` |
| `landing/generation-md/` | `/Volumes/nz_energy/bronze/landing/generation-md` |

Upload those folders to the Unity Catalog Volume before the pipeline reads them. Databricks Free Edition must not download from the EMI blob itself.
