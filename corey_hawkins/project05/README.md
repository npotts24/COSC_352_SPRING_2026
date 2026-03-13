## Getting Started

*   Docker installed on your system.

### Project Files

*   `histogram.R`: The R script for data scraping, parsing, and visualization.

*   `Dockerfile`: Defines the Docker image with R and necessary packages.

*   `run.sh`: A bash script to build the Docker image and run the analysis.

### How to Run

1.  **Save the files:** Ensure `histogram.R`, `Dockerfile`, and `run.sh` are in the same directory.

2.  **Make `run.sh` executable:**

    ```bash

    chmod +x run.sh

    ```

3.  **Execute the script:**

    ```bash

    ./run.sh

    ```

This command will:

*   Build the Docker image named `homicide-histogram-app`.

*   Run a container from that image.

*   Execute the `histogram.R` script within the container.

*   Print the resulting histogram directly to your terminal.

## Output

The script will output a histogram representing the distribution of victim ages. The histogram will be printed to standard output in your terminal.

   
