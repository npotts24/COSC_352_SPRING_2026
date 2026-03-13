FROM rocker/verse:4.3

# System dependencies are already included in rocker/verse
# Install any additional system libraries if needed  
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy the R script
COPY histogram.R /app/histogram.R

# Run the R script and capture output (using JSON/exec form for proper signal handling)
CMD ["Rscript", "/app/histogram.R"]
