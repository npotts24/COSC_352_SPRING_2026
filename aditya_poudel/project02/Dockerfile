# Use the official Python image 
FROM python:3.11-slim

# Set the working directory inside the container
WORKDIR /app

# Copy the Python script into the container
COPY table_to_DFS_to_CSV.py .

# Install pandas (we are allowed to use standard Python + pandas)
RUN pip install --no-cache-dir pandas

# Default command to run when container starts
# Arguments (URL or file path) will be passed when running the container
ENTRYPOINT ["python", "table_to_DFS_to_CSV.py"]