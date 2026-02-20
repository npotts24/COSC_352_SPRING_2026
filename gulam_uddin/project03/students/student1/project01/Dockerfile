# Use a lightweight Python image
FROM python:3.11-alpine

# Copy the student project files into the container
COPY . /app
WORKDIR /app

# Run main.py with the student name as an argument
ENTRYPOINT ["python", "main.py"]
