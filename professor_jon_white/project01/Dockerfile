# Use an official Python runtime as a parent image
FROM python:3.10-slim

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY hello-world.py /app

# Install any needed packages specified in requirements.txt (if any)
# RUN pip install --no-cache-dir -r requirements.txt

# Define the command to run the script when the container starts
ENTRYPOINT ["python", "hello-world.py"]
