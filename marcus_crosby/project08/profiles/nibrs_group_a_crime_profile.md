# csvprof report

Rows profiled: **247869**

## RowID
- Type: int
- Rows: 247869
- Nulls: 0
- Non-null: 247869
- Distinct: ~236732
- Min/Max: 1 / 249233
- Mean/Median/Std Dev: 124613.141744 / 124965.500000 / 71998.464781
- Top values: 249205 (1), 249206 (1), 249207 (1), 249208 (1), 249209 (1)
- Percentiles: p25=60841.500000, p75=186889.500000, p90=225923.500000
- Notes: median and percentiles come from a bounded reservoir sample (size=4096); top values are approximate heavy hitters (capacity=32); distinct count is approximate once cardinality exceeds 1024 values

## CCNumber
- Type: int
- Rows: 247869
- Nulls: 0
- Non-null: 247869
- Distinct: ~228887
- Min/Max: 181000098 / 260435684
- Mean/Median/Std Dev: 237070203.861406 / 240104560.0 / 12038473.758938
- Top values: 250203343 (2), 250204004 (2), 250204008 (2), 250207966 (3), 250203294 (1)
- Percentiles: p25=230204713.500000, p75=250206612.250000, p90=251005901.500000
- Notes: median and percentiles come from a bounded reservoir sample (size=4096); top values are approximate heavy hitters (capacity=32); distinct count is approximate once cardinality exceeds 1024 values

## CrimeDateTime
- Type: text
- Rows: 247869
- Nulls: 0
- Non-null: 247869
- Distinct: ~138118
- Top values: 2/13/2025 5:00:00 AM (4), 2/12/2025 3:30:00 PM (2), 2/14/2025 6:20:00 PM (2), 2/14/2025 7:30:00 PM (2), 1/28/2025 4:35:00 PM (4)
- Notes: top values are approximate heavy hitters (capacity=32); distinct count is approximate once cardinality exceeds 1024 values; average trimmed length 20.2 characters

## CrimeCode
- Type: text
- Rows: 247869
- Nulls: 0
- Non-null: 247869
- Distinct: 43
- Top values: 13B (41240), 290 (37367), 240 (26708), 13A (23788), 23F (17623)
- Notes: mixed numeric and free-text values prevented numeric inference; top values are approximate heavy hitters (capacity=32); average trimmed length 3.0 characters

## Description
- Type: categorical
- Rows: 247869
- Nulls: 0
- Non-null: 247869
- Distinct: 28
- Top values: COMMON ASSAULT (41240), VANDALISM (37367), AUTO THEFT (26708), LARCENY (23981), AGG. ASSAULT (23788)

## Inside_Outside
- Type: categorical
- Rows: 247869
- Nulls: 269
- Non-null: 247600
- Distinct: 2
- Top values: I (141307), O (106293)

## Weapon
- Type: categorical
- Rows: 247869
- Nulls: 157953
- Non-null: 89916
- Distinct: 20
- Top values: PERSONAL_WEAPONS (53348), HANDGUN (10246), KNIFE_CUTTING_INSTRUMENT (6345), FIREARM (5337), BLUNT_OBJECT (5209)

## Shooting
- Type: bool
- Rows: 247869
- Nulls: 245786
- Non-null: 2083
- Distinct: 2
- Top values: Y (2081), N (2)
- Notes: true=2081 false=2

## Post
- Type: text
- Rows: 247869
- Nulls: 417
- Non-null: 247452
- Distinct: 203
- Top values: 116 (8), 126 (7), 227 (2), 325 (2), 513 (4)
- Notes: mixed numeric and free-text values prevented numeric inference; top values are approximate heavy hitters (capacity=32); average trimmed length 3.0 characters

## Gender
- Type: categorical
- Rows: 247869
- Nulls: 36612
- Non-null: 211257
- Distinct: 3
- Top values: F (113002), M (97263), U (992)

## Age
- Type: int
- Rows: 247869
- Nulls: 40655
- Non-null: 207214
- Distinct: 106
- Min/Max: 0 / 121
- Mean/Median/Std Dev: 39.038955 / 36.0 / 15.972647
- Top values: 29 (1200), 28 (178), 30 (334), 32 (105), 36 (50)
- Percentiles: p25=27.0, p75=50.0, p90=62.0
- Notes: median and percentiles come from a bounded reservoir sample (size=4096); top values are approximate heavy hitters (capacity=32)

## Race
- Type: categorical
- Rows: 247869
- Nulls: 56556
- Non-null: 191313
- Distinct: 6
- Top values: BLACK_OR_AFRICAN_AMERICAN (135226), WHITE (45454), UNKNOWN (4590), ASIAN (4051), NATIVE_HAWAIIAN_OR_OTHER_PACIFIC_ISLANDER (1083)

## Ethnicity
- Type: categorical
- Rows: 247869
- Nulls: 59481
- Non-null: 188388
- Distinct: 6
- Top values: NOT_HISPANIC_OR_LATINO (103066), UNKNOWN (67784), HISPANIC_OR_LATINO (15868), MIDDLE_EASTERN (877), EAST_ASIAN (471)

## Location
- Type: categorical
- Rows: 247869
- Nulls: 1200
- Non-null: 246669
- Distinct: ~15535
- Top values: 10 W MADISON ST (3), 1900 N CHESTER ST (2), 400 N CLINTON ST (2), 1000 E 20TH ST (1), 2900 ROCKROSE AVE (3)
- Notes: top values are approximate heavy hitters (capacity=32); distinct count is approximate once cardinality exceeds 1024 values

## Old_District
- Type: categorical
- Rows: 247869
- Nulls: 157254
- Non-null: 90615
- Distinct: 9
- Top values: NORTHEAST (13706), SOUTHEAST (12722), SOUTHERN (11022), CENTRAL (10622), NORTHERN (9621)

## New_District
- Type: categorical
- Rows: 247869
- Nulls: 84230
- Non-null: 163639
- Distinct: 10
- Top values: CENTRAL (23424), SOUTHEAST (21846), SOUTHERN (19403), NORTHEAST (18512), NORTHERN (17816)

## Neighborhood
- Type: categorical
- Rows: 247869
- Nulls: 55290
- Non-null: 192579
- Distinct: 290
- Top values: DOWNTOWN (7271), FRANKFORD (275), MOUNT VERNON (14), FELLS POINT (5), BROOKLYN (7)
- Notes: top values are approximate heavy hitters (capacity=32)

## Latitude
- Type: float
- Rows: 247869
- Nulls: 271
- Non-null: 247598
- Distinct: ~60976
- Min/Max: 0.0 / 39.375381
- Mean/Median/Std Dev: 39.305954 / 39.301356 / 0.084532
- Top values: 39.296509 (2), 39.298616 (3), 39.312517 (2), 39.28214 (1), 39.297484 (1)
- Percentiles: p25=39.287314, p75=39.326975, p90=39.349060
- Notes: median and percentiles come from a bounded reservoir sample (size=4096); top values are approximate heavy hitters (capacity=32); distinct count is approximate once cardinality exceeds 1024 values

## Longitude
- Type: float
- Rows: 247869
- Nulls: 271
- Non-null: 247598
- Distinct: ~72559
- Min/Max: -76.728558 / 0.0
- Mean/Median/Std Dev: -76.616505 / -76.613182 / 0.159762
- Top values: -76.57053 (2), -76.588623 (2), -76.616557 (3), -76.530902 (1), -76.562501 (1)
- Percentiles: p25=-76.646594, p75=-76.586471, p90=-76.561007
- Notes: median and percentiles come from a bounded reservoir sample (size=4096); top values are approximate heavy hitters (capacity=32); distinct count is approximate once cardinality exceeds 1024 values

## GeoLocation
- Type: text
- Rows: 247869
- Nulls: 0
- Non-null: 247869
- Distinct: ~95384
- Top values: (39.296509,-76.57053) (2), (39.298616,-76.616557) (3), (39.312517,-76.588623) (2), (39.349324,-76.690503) (2), (39.277712,-76.615669) (1)
- Notes: top values are approximate heavy hitters (capacity=32); distinct count is approximate once cardinality exceeds 1024 values; average trimmed length 21.7 characters

## PremiseType
- Type: categorical
- Rows: 247869
- Nulls: 1
- Non-null: 247868
- Distinct: 39
- Top values: OTHER/RESIDENTIAL (90666), STREET (86988), CONVENIENCE STORE (12942), SHED/GARAGE (12339), OFFICE BUILDING (5811)
- Notes: top values are approximate heavy hitters (capacity=32)

## Total_Incidents
- Type: int
- Rows: 247869
- Nulls: 0
- Non-null: 247869
- Distinct: 1
- Min/Max: 1 / 1
- Mean/Median/Std Dev: 1.0 / 1.0 / 0.0
- Top values: 1 (247869)
- Percentiles: p25=1.0, p75=1.0, p90=1.0
- Notes: median and percentiles come from a bounded reservoir sample (size=4096)

## x
- Type: float
- Rows: 247869
- Nulls: 271
- Non-null: 247598
- Distinct: ~71745
- Min/Max: -76.728558 / 0.0
- Mean/Median/Std Dev: -76.616505 / -76.612340 / 0.159762
- Top values: -76.57053 (2), -76.588623 (2), -76.6165569999999 (3), -76.530902 (1), -76.5625009999999 (1)
- Percentiles: p25=-76.647036, p75=-76.584103, p90=-76.559966
- Notes: median and percentiles come from a bounded reservoir sample (size=4096); top values are approximate heavy hitters (capacity=32); distinct count is approximate once cardinality exceeds 1024 values

## y
- Type: float
- Rows: 247869
- Nulls: 271
- Non-null: 247598
- Distinct: ~59711
- Min/Max: 0.0 / 39.375381
- Mean/Median/Std Dev: 39.305954 / 39.301927 / 0.084532
- Top values: 39.2965090000001 (2), 39.298616 (3), 39.3125170000001 (2), 39.28214 (1), 39.2974840000001 (1)
- Percentiles: p25=39.286790, p75=39.326832, p90=39.349687
- Notes: median and percentiles come from a bounded reservoir sample (size=4096); top values are approximate heavy hitters (capacity=32); distinct count is approximate once cardinality exceeds 1024 values

