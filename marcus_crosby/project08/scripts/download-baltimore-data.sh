#!/usr/bin/env bash
set -euo pipefail

mkdir -p data

curl -L --fail --show-error \
  'https://hub.arcgis.com/api/download/v1/items/204beefe92a645d79fdf0969957bbdf8/csv?layers=0' \
  -o data/nibrs_group_a_crime.csv

curl -L --fail --show-error \
  'https://hub.arcgis.com/api/download/v1/items/691d65a5f85640e6aaa46930bd9dc102/csv?layers=1' \
  -o data/vacant_building_notices.csv
