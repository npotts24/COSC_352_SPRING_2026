FROM ubuntu:24.04

# Install Java, Go, and Kotlin
RUN apt-get update && apt-get install -y \
    openjdk-21-jdk \
    golang-go \
    kotlin \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy project files
COPY . /app

# Make run script executable
RUN chmod +x /app/run.sh

# Default command
ENTRYPOINT ["/app/run.sh"]
CMD ["data/numbers.txt"]
