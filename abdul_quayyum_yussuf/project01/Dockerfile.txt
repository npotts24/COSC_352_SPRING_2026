# Official Python runtime as parent image
FROM python:3.10-slim

# Sets the working directory
WORKDIR /app

# Copy current directory contents into  the container at /app
COPY hello-ayo.py /app

# Define the command to run scripts when the container starts.
ENTRYPOINT ["python", "hello-ayo.py"]
