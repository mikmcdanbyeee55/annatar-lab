ARG BUILD_VERSION=UNKNOWN

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV POETRY_VERSION=1.7.1

# Install Poetry
RUN pip install "poetry==$POETRY_VERSION"

# Set the working directory
WORKDIR /app

# Copy the pyproject.toml and poetry.lock files
COPY pyproject.toml poetry.lock* /app/

# Install runtime dependencies using Poetry
RUN poetry config virtualenvs.create false \
    && poetry install --no-dev --no-root --no-interaction --no-ansi

# Copy the rest of your application's code
COPY annatar /app/annatar

# Set environment variables for the final stage
ENV DB_PATH=/app/data/annatar.db
ENV NUM_WORKERS 4

VOLUME /app/data
WORKDIR /app

# Install Node.js and npm
RUN apt-get update \
    && apt-get install -y nodejs npm procps \
    && rm -rf /var/lib/apt/lists/*

# Install PM2
RUN npm install pm2 -g

# Copy static and template files
COPY ./static /app/static
COPY ./templates /app/templates

# Use PM2 to start your application
CMD ["pm2-runtime", "--interpreter", "python", "run.py"]
