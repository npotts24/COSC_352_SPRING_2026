# Baltimore City Homicide Dashboard (2025)

This project is a reproducible R Shiny dashboard that scrapes, parses, and visualizes real-world homicide data from Baltimore City. The application is fully Dockerized to ensure it runs consistently across different environments.

## 📊 Dashboard Features
- **Real-Time Web Scraping**: Automatically pulls the latest 2025 victim data from the "Chams Page" Baltimore homicide blog.
- **Interactive Statistics**: Displays total homicides, case clearance rates, and average victim age based on user filters.
- **Monthly Trends**: A Plotly scatter plot showing the frequency of incidents over time.
- **Method Analysis**: A bar chart visualizing the distribution of homicide methods (e.g., shooting, stabbing).
- **Geospatial Mapping**: A Leaflet map showing incident locations (currently using center-point coordinates).
- **Custom Filters**: Users can filter data by Year, Victim Age, and Homicide Method.

---

## 🚀 Part 2: Running the Dashboard

### Prerequisites
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running.
- (For Mac M-series users): Ensure Docker is configured to allow `x86_64` emulation.

### Execution Instructions
1. **Clone the Repository**:
   Navigate to the project folder in your terminal.
   
2. **Make the Script Executable**:
   ```bash
   chmod +x run_dashboard.sh
