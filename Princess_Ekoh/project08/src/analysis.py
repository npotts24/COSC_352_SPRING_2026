import pandas as pd
import os

base = os.path.dirname(__file__)

# Load datasets
requests = pd.read_csv(os.path.join(base, "../data/311.csv"))
vacant = pd.read_csv(os.path.join(base, "../data/vacant.csv"))

print("\n=== DATA LOADED ===")
print("311 rows:", len(requests))
print("Vacant rows:", len(vacant))

# Clean column names
requests.columns = [c.lower().strip() for c in requests.columns]
vacant.columns = [c.lower().strip() for c in vacant.columns]

# Normalize district column names
if "district" not in requests.columns:
    if "councildistrict" in requests.columns:
        requests = requests.rename(columns={"councildistrict": "district"})

if "district" not in vacant.columns:
    if "council_district" in vacant.columns:
        vacant = vacant.rename(columns={"council_district": "district"})
    elif "councildistrict" in vacant.columns:
        vacant = vacant.rename(columns={"councildistrict": "district"})

# Ensure required column exists
if "district" not in requests.columns or "district" not in vacant.columns:
    print("ERROR: 'district' column missing in one of the datasets")
    exit()

# Convert each dataset into district-level counts
requests_by_district = requests.groupby("district").size().reset_index(name="request_count")
vacant_by_district = vacant.groupby("district").size().reset_index(name="vacant_count")

# Merge datasets
merged = pd.merge(requests_by_district, vacant_by_district, on="district")

print("\n=== MERGED DATA (preview) ===")
print(merged.head())

# Correlation analysis
print("\n=== CORRELATION ===")
corr = merged[["request_count", "vacant_count"]].corr()
print(corr)

# Key insight value
corr_value = corr.iloc[0, 1]
print("\nCorrelation coefficient:", corr_value)

if corr_value > 0:
    print("Positive relationship: more vacant properties → more 311 requests")
elif corr_value < 0:
    print("Negative relationship: inverse relationship observed")
else:
    print("No clear relationship observed")

# Top districts
print("\n=== TOP 5 DISTRICTS (311 requests) ===")
print(merged.sort_values("request_count", ascending=False).head())

print("\n=== TOP 5 DISTRICTS (vacant properties) ===")
print(merged.sort_values("vacant_count", ascending=False).head())