# Use an official Python runtime as a parent image
FROM python:3.12-slim

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file and install dependencies
COPY hello-world.py /app
# Copy the rest of the application code

# Define the command to run your script when the container starts
ENTRYPOINT ["python", "hello-world.py"]
