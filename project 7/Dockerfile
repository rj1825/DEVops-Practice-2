# Build Stage (Use lightweight Python base image)
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy dependency definition
COPY app/requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY app/ .

# Expose port
EXPOSE 5000

# Run Flask application
CMD ["python", "app.py"]
