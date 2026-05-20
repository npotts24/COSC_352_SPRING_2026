# csvprof report

Rows profiled: **290**

## neighborhood
- Type: text
- Rows: 290
- Nulls: 0
- Non-null: 290
- Distinct: 290
- Top values: BLYTHEWOOD (1), DUNDALK MARINE TERMINAL (1), BALTIMORE PENINSULA (1), BELLONA-GITTINGS (1), BURLEITH-LEIGHTON (1)
- Notes: top values are approximate heavy hitters (capacity=32); average trimmed length 13.4 characters

## crime_events
- Type: int
- Rows: 290
- Nulls: 0
- Non-null: 290
- Distinct: 261
- Min/Max: 1 / 7388
- Mean/Median/Std Dev: 664.065517 / 409.500000 / 791.477388
- Top values: 22 (2), 35 (2), 46 (2), 73 (2), 76 (2)
- Percentiles: p25=202.250000, p75=813.500000, p90=1481.400000
- Notes: top values are approximate heavy hitters (capacity=32)

## crime_total_incidents
- Type: int
- Rows: 290
- Nulls: 0
- Non-null: 290
- Distinct: 261
- Min/Max: 1 / 7388
- Mean/Median/Std Dev: 664.065517 / 409.500000 / 791.477388
- Top values: 22 (2), 35 (2), 46 (2), 73 (2), 76 (2)
- Percentiles: p25=202.250000, p75=813.500000, p90=1481.400000
- Notes: top values are approximate heavy hitters (capacity=32)

## violent_events
- Type: int
- Rows: 290
- Nulls: 0
- Non-null: 290
- Distinct: 217
- Min/Max: 0 / 3022
- Mean/Median/Std Dev: 217.686207 / 132.500000 / 284.925429
- Top values: 7 (6), 23 (5), 2 (3), 0 (2), 16 (2)
- Percentiles: p25=55.250000, p75=263.750000, p90=505.600000
- Notes: top values are approximate heavy hitters (capacity=32)

## shooting_events
- Type: int
- Rows: 290
- Nulls: 0
- Non-null: 290
- Distinct: 31
- Min/Max: 0 / 74
- Mean/Median/Std Dev: 4.917241 / 2.0 / 8.268842
- Top values: 0 (81), 1 (48), 2 (35), 4 (23), 8 (14)
- Percentiles: p25=0.0, p75=6.0, p90=12.100000

## vacant_notices
- Type: int
- Rows: 290
- Nulls: 0
- Non-null: 290
- Distinct: 89
- Min/Max: 0 / 750
- Mean/Median/Std Dev: 40.720690 / 5.0 / 97.612722
- Top values: 0 (79), 2 (28), 3 (15), 1 (13), 4 (8)
- Percentiles: p25=0.0, p75=24.750000, p90=126.0
- Notes: top values are approximate heavy hitters (capacity=32)

## active_vacant_notices
- Type: int
- Rows: 290
- Nulls: 0
- Non-null: 290
- Distinct: 89
- Min/Max: 0 / 750
- Mean/Median/Std Dev: 40.720690 / 5.0 / 97.612722
- Top values: 0 (79), 2 (28), 3 (15), 1 (13), 4 (8)
- Percentiles: p25=0.0, p75=24.750000, p90=126.0
- Notes: top values are approximate heavy hitters (capacity=32)

## closed_or_abated_vacant_notices
- Type: int
- Rows: 290
- Nulls: 0
- Non-null: 290
- Distinct: 1
- Min/Max: 0 / 0
- Mean/Median/Std Dev: 0.0 / 0.0 / 0.0
- Top values: 0 (290)
- Percentiles: p25=0.0, p75=0.0, p90=0.0

## crime_events_per_active_vacant_notice
- Type: float
- Rows: 290
- Nulls: 79
- Non-null: 211
- Distinct: 209
- Min/Max: 1.261017 / 1299.0
- Mean/Median/Std Dev: 106.158133 / 42.428571 / 154.908967
- Top values: 105.000000 (1), 1299.000000 (1), 176.000000 (1), 186.000000 (1), 237.000000 (1)
- Percentiles: p25=13.325397, p75=145.500000, p90=277.411765
- Notes: top values are approximate heavy hitters (capacity=32)
