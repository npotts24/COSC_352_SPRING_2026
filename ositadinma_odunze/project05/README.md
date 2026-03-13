# Baltimore City Homicide Data Analysis



## Overview

Scrapes and analyzes Baltimore City homicide data from chamspage.blogspot.com, focusing on victim age distribution.

## Quick Start
```bash
chmod +x run.sh
./run.sh
```

## What It Does

1. Scrapes homicide data from blog
2. Cleans and parses victim ages
3. Creates age distribution histogram
4. Outputs tabular results to terminal

## Chosen Statistic

**Victim Age Distribution** - Shows which age groups are most affected by violence, informing intervention programs and policy decisions.

## Prerequisites

- Docker installed and running

## Output
```
Age Range    Count    Percentage    Bar
0-9            2       4.0%         ████
10-19          8      16.0%         ████████████████
20-29         18      36.0%         ████████████████████████
```

Plus summary statistics (mean, median, min, max).

## Files

- `histogram.R` - R script for analysis
- `Dockerfile` - Docker environment
- `run.sh` - Build and run script
- `README.md` - This file



