# Use an official Python runtime as a parent image
FROM python:3.12-alpine

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy the current directory contents into the container
COPY hello-world.py /app

# Install any needed packages (if you have a requirements.txt file)
# RUN pip install --no-cache-dir -r requirements.txt

# Define the command to run the script when the container starts
ENTRYPOINT ["python", "hello-world.py"]
