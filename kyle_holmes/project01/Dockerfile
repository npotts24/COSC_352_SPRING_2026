# Use the latest official Python image
FROM python:3.11-slim
# Set working directory inside container
WORKDIR /app
# Copy the Python file into the container
COPY hello-world.py /app
# Install dependencies if needed (uncomment if you have requirements.txt)
# COPY requirements.txt
# RUN pip install --no-cache-dir -r requirements.txt
# Command to run the script
ENTRYPOINT ["python", "hello-world.py"]