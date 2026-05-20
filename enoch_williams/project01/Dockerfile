# Use official Python 3.10 image
FROM python:3.10-slim

# Set working directory inside container
WORKDIR /app

# Copy script into container
COPY hello-world.py /app

# Run the script by default
ENTRYPOINT ["python", "hello-world.py"]
