# csvprof report

Rows profiled: **11809**

## X
- Type: float
- Rows: 11809
- Nulls: 0
- Non-null: 11809
- Distinct: ~11956
- Min/Max: 1394085.138026 / 1445250.805380
- Mean/Median/Std Dev: 1415998.576748 / 1412790.879650 / 9137.065747
- Top values: 1398516.99727289 (1), 1406825.42849064 (1), 1406870.87164122 (1), 1406933.21830131 (1), 1406974.96690547 (1)
- Percentiles: p25=1409713.401389, p75=1424797.503357, p90=1429775.708213
- Notes: median and percentiles come from a bounded reservoir sample (size=4096); top values are approximate heavy hitters (capacity=32); distinct count is approximate once cardinality exceeds 1024 values

## Y
- Type: float
- Rows: 11809
- Nulls: 0
- Non-null: 11809
- Distinct: ~11226
- Min/Max: 566208.284502 / 621353.766074
- Mean/Median/Std Dev: 595960.858263 / 595858.573954 / 7864.092143
- Top values: 588821.179892644 (1), 581856.21416381 (1), 581914.558207229 (1), 585199.817056641 (1), 600668.310069725 (1)
- Percentiles: p25=591081.240005, p75=599359.931371, p90=606015.008202
- Notes: median and percentiles come from a bounded reservoir sample (size=4096); top values are approximate heavy hitters (capacity=32); distinct count is approximate once cardinality exceeds 1024 values

## OBJECTID
- Type: int
- Rows: 11809
- Nulls: 0
- Non-null: 11809
- Distinct: ~11194
- Min/Max: 9 / 246997
- Mean/Median/Std Dev: 78192.206283 / 59047.500000 / 64504.755534
- Top values: 246997 (1), 243947 (1), 243962 (1), 243972 (1), 243974 (1)
- Percentiles: p25=23606.750000, p75=116387.750000, p90=180627.0
- Notes: median and percentiles come from a bounded reservoir sample (size=4096); top values are approximate heavy hitters (capacity=32); distinct count is approximate once cardinality exceeds 1024 values

## NoticeNum
- Type: text
- Rows: 11809
- Nulls: 0
- Non-null: 11809
- Distinct: ~11618
- Top values: 1904620A (1), 1394672A (1), 1648557A (1), 1751237A (1), 1945546A (1)
- Notes: top values are approximate heavy hitters (capacity=32); distinct count is approximate once cardinality exceeds 1024 values; average trimmed length 7.7 characters

## DateNotice
- Type: text
- Rows: 11809
- Nulls: 0
- Non-null: 11809
- Distinct: ~11555
- Top values: 2023/07/12 10:57:00+00 (1), 2016/05/23 16:15:00+00 (1), 2018/03/14 23:00:00+00 (1), 2019/01/07 08:22:00+00 (1), 2020/10/10 03:13:00+00 (1)
- Notes: top values are approximate heavy hitters (capacity=32); distinct count is approximate once cardinality exceeds 1024 values; average trimmed length 22.0 characters

## DateCancel
- Type: text
- Rows: 11809
- Nulls: 11809
- Non-null: 0
- Distinct: 0
- Notes: column only contains null-like values; average trimmed length 0.0 characters

## DateAbate
- Type: text
- Rows: 11809
- Nulls: 11809
- Non-null: 0
- Distinct: 0
- Notes: column only contains null-like values; average trimmed length 0.0 characters

## NT
- Type: categorical
- Rows: 11809
- Nulls: 0
- Non-null: 11809
- Distinct: 1
- Top values: Vacant (11809)

## OWNER_ABBR
- Type: categorical
- Rows: 11809
- Nulls: 10710
- Non-null: 1099
- Distinct: 5
- Top values: MCC (990), HABC (99), USA (7), HUD (2), VA (1)

## HousingMarketTypology2023
- Type: categorical
- Rows: 11809
- Nulls: 18
- Non-null: 11791
- Distinct: 10
- Top values: J (5068), I (4004), G (1293), F (368), E (362)

## Council_District
- Type: int
- Rows: 11809
- Nulls: 0
- Non-null: 11809
- Distinct: 14
- Min/Max: 1 / 14
- Mean/Median/Std Dev: 9.079262 / 9.0 / 2.618367
- Top values: 9 (4247), 7 (1930), 12 (1475), 13 (1072), 6 (949)
- Percentiles: p25=7.0, p75=11.0, p90=13.0
- Notes: median and percentiles come from a bounded reservoir sample (size=4096)

## Neighborhood
- Type: categorical
- Rows: 11809
- Nulls: 0
- Non-null: 11809
- Distinct: 211
- Top values: Carrollton Ridge (750), Broadway East (725), Sandtown-Winchester (611), East Baltimore Midway (333), Central Park Heights (321)
- Notes: top values are approximate heavy hitters (capacity=32)

## BLOCKLOT
- Type: text
- Rows: 11809
- Nulls: 0
- Non-null: 11809
- Distinct: ~11756
- Top values: 8102E020 (1), 3347E040 (1), 3350E011 (1), 3350E021 (1), 3350E023 (1)
- Notes: mixed numeric and free-text values prevented numeric inference; top values are approximate heavy hitters (capacity=32); distinct count is approximate once cardinality exceeds 1024 values; average trimmed length 8.0 characters

## Address
- Type: text
- Rows: 11809
- Nulls: 22
- Non-null: 11787
- Distinct: ~12202
- Top values: 1400 INVERNESS AVE (1), 1404 INVERNESS AVE (1), 15 S WICKHAM ROAD (1), 3515 PELHAM AVE (1), 3534 PELHAM AVE (1)
- Notes: top values are approximate heavy hitters (capacity=32); distinct count is approximate once cardinality exceeds 1024 values; average trimmed length 16.5 characters

