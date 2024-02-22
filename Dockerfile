ARG BUILD_VERSION=UNKNOWN

# --- Build Stage ---
FROM python:3.11 as builder

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV POETRY_VERSION=1.7.1
# Set default health check port (you can change it during runtime)
ENV HEALTH_CHECK_PORT=8000

# Install Poetry
RUN pip install "poetry==$POETRY_VERSION"

# Set the working directory in the builder stage
WORKDIR /app

# Create the '/app/data' directory in the build stage
RUN mkdir -p /app/data

# Copy the pyproject.toml and poetry.lock files
COPY pyproject.toml poetry.lock* /app/

# Install runtime dependencies using Poetry and create wheels for them
RUN poetry config virtualenvs.create false \
    && poetry install --no-dev --no-root --no-interaction --no-ansi \
    && poetry export -f requirements.txt --output requirements.txt --without-hashes \
    && pip wheel --no-cache-dir --no-deps --wheel-dir /tmp/wheels -r requirements.txt

# Copy the rest of your application's code
COPY annatar /app/annatar

# Build your application using Poetry
RUN poetry build

# --- Final Stage ---
FROM python:3.11-slim as final

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DB_PATH=/app/data/annatar.db \
    NUM_WORKERS=4

VOLUME /app/data
WORKDIR /app

# Create the '/app/data' directory in the final stage
RUN mkdir -p /app/data

# Copy wheels and built wheel from the builder stage
COPY --from=builder /app/dist/*.whl /tmp/wheels/
COPY --from=builder /tmp/wheels/*.whl /tmp/wheels/

# Install the application package along with all dependencies
RUN pip install /tmp/wheels/*.whl && rm -rf /tmp/wheels

# Copy static and template files
COPY ./static /app/static
COPY ./templates /app/templates

COPY run.py /app/run.py

# Expose the health check port
EXPOSE $HEALTH_CHECK_PORT

# Health check
HEALTHCHECK --interval=30s --timeout=5s \
    CMD curl -f http://localhost:$HEALTH_CHECK_PORT/ || exit 1

CMD ["python", "run.py"]
