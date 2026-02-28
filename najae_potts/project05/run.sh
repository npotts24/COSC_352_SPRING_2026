#!/bin/bash
# Baltimore Homicide Data Project - Build and Run Script
# This script builds the Docker image and runs the analysis

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project configuration
PROJECT_NAME="baltimore-homicide-analysis"
IMAGE_NAME="$PROJECT_NAME:latest"
CONTAINER_NAME="$PROJECT_NAME-container"

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Baltimore City Homicide Data Analysis - Docker Runner${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}\n"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Error: Docker is not installed.${NC}"
    echo "Please install Docker from https://www.docker.com/products/docker-desktop"
    exit 1
fi

echo -e "${YELLOW}Step 1: Checking Docker installation...${NC}"
echo -e "${GREEN}✓ Docker found: $(docker --version)${NC}\n"

# Check if Dockerfile exists
if [ ! -f "Dockerfile" ]; then
    echo -e "${RED}✗ Error: Dockerfile not found in current directory.${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 2: Building Docker image...${NC}"
echo -e "Image name: ${BLUE}$IMAGE_NAME${NC}"
echo "This may take a few minutes on first run (downloading R base image, installing packages)..."

if docker build -t "$IMAGE_NAME" .; then
    echo -e "${GREEN}✓ Docker image built successfully${NC}\n"
else
    echo -e "${RED}✗ Error: Failed to build Docker image${NC}"
    exit 1
fi

# Remove any existing container with the same name
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${YELLOW}Removing existing container...${NC}"
    docker rm -f "$CONTAINER_NAME" > /dev/null
fi

echo -e "${YELLOW}Step 3: Running Docker container...${NC}"
echo -e "This will scrape data from chamspage.blogspot.com and generate analysis...\n"

# Run the container
# Mount current directory to access output files (histogram.png)
if docker run \
    --name "$CONTAINER_NAME" \
    -v "$(pwd):/project" \
    "$IMAGE_NAME"; then
    
    echo -e "\n${GREEN}✓ Analysis completed successfully!${NC}"
    
    # Check if histogram.png was created
    if [ -f "histogram.png" ]; then
        echo -e "${GREEN}✓ Histogram saved as: histogram.png${NC}"
    fi
    
    # Clean up container
    docker rm -f "$CONTAINER_NAME" > /dev/null
    
    echo -e "\n${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Analysis Output:${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}\n"
    
else
    echo -e "${RED}✗ Error: Docker container failed${NC}"
    docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1 || true
    exit 1
fi
