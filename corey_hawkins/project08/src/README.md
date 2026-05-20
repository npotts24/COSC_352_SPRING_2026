# Baltimore City Open Data Analysis - Part 2

This project analyzes two datasets from the Baltimore City Open Data portal to answer a specific research question by correlating information across both files. It builds upon the code and concepts from Part 1, specifically reusing data loading functionalities.

## Datasets Used

1.  **Dataset 1: Baltimore City Public School Locations**

    *   **Name:** Baltimore City Public School Locations

    *   **Source URL:** `https://data.baltimorecity.gov/Education/Baltimore-City-Public-School-Locations/3k2p-3j3c`

    *   **Description:** This dataset contains detailed information about each public school within Baltimore City, including its name, address, type, and geographical coordinates (latitude and longitude).

    *   **Key Columns Used:** `SchoolName`, `Latitude`, `Longitude`

2.  **Dataset 2: 311 Service Requests**

    *   **Name:** 311 Service Requests

    *   **Source URL:** `https://data.baltimorecity.gov/Service-Requests/311-Service-Requests/e93v-4jry`

    *   **Description:** This dataset comprises records of non-emergency service requests submitted by citizens to Baltimore City agencies through the 311 system. It includes the type of service requested, the date it was submitted, its status, and its geographical coordinates.

    *   **Key Columns Used:** `RequestType`, `Latitude`, `Longitude`

## Research Question

What are the most frequent types of 311 service requests located within a 0.5-mile radius of Baltimore City Public Schools?

## Answer

After loading the school locations and 311 service requests datasets, and defining a search radius of approximately 0.5 miles (0.8 kilometers) around each school, the analysis revealed the following distribution of 311 service requests:


Specifically, the most common types of service requests observed near school locations were **[State the top request type, e.g., 'Pothole Repair']**, accounting for [Insert specific number or percentage] of the requests within the defined proximity. Following this, **[State the second top request type, e.g., 'Graffiti Removal']** was the next most frequent with [Insert specific number or percentage]. This suggests that [Briefly interpret the finding - e.g., 'areas around schools experience a higher volume of requests related to infrastructure maintenance and general upkeep'].

Limitations

*   **Geocoding Accuracy:** The analysis relies on the accuracy of the `Latitude` and `Longitude` coordinates provided in both datasets. Inaccurate or missing coordinates for either schools or service requests could lead to misclassification or exclusion of relevant data points.

*   **Radius Definition:** The chosen radius (0.5 miles) is an approximation. The actual "vicinity" of a school might be perceived differently (e.g., focusing only on the immediate block vs. a wider neighborhood). Furthermore, the Haversine formula calculates distance on a sphere, which is a simplification of the Earth's actual shape and doesn't account for road networks.
