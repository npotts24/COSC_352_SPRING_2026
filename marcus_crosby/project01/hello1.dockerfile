#  Python image
FROM python:3.12-slim

# Working directory
WORKDIR /hello1

# Script
COPY hello1.py .

# Run 
CMD ["python", "hello1.py"]