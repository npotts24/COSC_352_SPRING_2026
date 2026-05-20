# Use an official Python runtime as a parent image
FROM python:3.10-slim

# Set the working directory in the container
WORKDIR /app

# Copy the currnet directory contents into the container at /app
COPY hello-world.py /app

#Define the command to run the specific script when the container starts
ENTRYPOINT ["python", "hello-world.py"]