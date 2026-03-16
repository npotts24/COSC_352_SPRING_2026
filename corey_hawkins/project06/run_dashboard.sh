# !/bin/bash


IMAGE_NAME="baltimore-homicide-dashboard"

CONTAINER_NAME="homicide_dashboard_app"

PORT=3838 

#  Script Logic 

echo "Starting the Baltimore Homicide Dashboard setup..."

# Build the Docker image

echo ""

echo "Building Docker image: ${IMAGE_NAME}"

echo ""


# --no-cache forces a rebuild of all layers

docker build --no-cache -t ${IMAGE_NAME} .

# Check if the build was successful

if [ $? -ne 0 ]; then

  echo ""

  echo "ERROR: Docker image build failed. Please check the Dockerfile and your code."

  echo ""

  exit 1

fi

echo "Docker image built successfully."

echo ""

# Stop and remove any existing container with the same name

echo ""

echo "Stopping and removing existing container (if any): ${CONTAINER_NAME}"

echo ""

docker stop ${CONTAINER_NAME} > /dev/null 2>&1

docker rm ${CONTAINER_NAME} > /dev/null 2>&1

echo "Existing container stopped and removed (if it existed)."

echo ""

# Run the Docker container

echo ""

echo "Running Docker container: ${CONTAINER_NAME}"

echo ""

echo "Mapping host port ${PORT} to container port ${PORT}"

echo ""

# start the app

docker run -d -p ${PORT}:${PORT} --name ${CONTAINER_NAME} ${IMAGE_NAME}

# Checks if the container started successfully

if [ $? -ne 0 ]; then

  echo ""

  echo "ERROR: Failed to run the Docker container."

  echo "Please check Docker logs for ${CONTAINER_NAME} using: docker logs ${CONTAINER_NAME}"

  echo ""

  exit 1

fi

echo "Docker container '${CONTAINER_NAME}' started successfully."

echo ""

# Print instructions for accessing the dashboard

echo ""

echo "Baltimore Homicide Dashboard is running!"

echo "You can now access it in your browser at:"

echo ""

echo "  http://localhost:${PORT}"

echo ""

echo "To view container logs, use: docker logs ${CONTAINER_NAME}"

echo "To stop the container, use: docker stop ${CONTAINER_NAME}"

echo "To remove the container, use: docker rm ${CONTAINER_NAME}"

echo ""

exit 0
