# Use the official Python image
FROM python:3.11-slim as base

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DB_PATH=/app/data/annatar.db
ENV NUM_WORKERS 4

VOLUME /app/data
WORKDIR /app

# Copy static and template files
COPY ./static /app/static
COPY ./templates /app/templates

COPY run.py /app/run.py

# Install Node.js and npm
RUN apt-get update \
    && apt-get install -y nodejs npm \
    && rm -rf /var/lib/apt/lists/*

# Install PM2
RUN npm install pm2 -g

# Install your Python dependencies
COPY pyproject.toml poetry.lock* /app/
RUN pip install poetry \
    && poetry config virtualenvs.create false \
    && poetry install --no-dev --no-root --no-interaction --no-ansi

# Copy the rest of your application's code
COPY annatar /app/annatar

# Build your application using Poetry
RUN poetry build

# Use PM2 to start your application
CMD ["pm2-runtime", "--interpreter", "python", "run.py"]
