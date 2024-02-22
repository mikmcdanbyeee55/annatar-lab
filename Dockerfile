# --- Build Stage ---
FROM python:3.11 as builder

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    POETRY_VERSION=1.7.1

# Install Poetry
RUN pip install "poetry==$POETRY_VERSION"

# Set the working directory in the builder stage
WORKDIR /app

# Copy only the poetry files and install dependencies
COPY pyproject.toml poetry.lock* /app/
RUN poetry config virtualenvs.create false \
    && poetry install --no-dev --no-root --no-interaction --no-ansi \
    && poetry export -f requirements.txt --output requirements.txt --without-hashes \
    && pip wheel --no-cache-dir --no-deps --wheel-dir /tmp/wheels -r requirements.txt

# Copy the entire application
COPY . /app/

# --- Final Stage ---
FROM python:3.11-slim as final

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DB_PATH=/app/data/annatar.db \
    NUM_WORKERS=4

VOLUME /app/data
WORKDIR /app

# Copy wheels and built wheel from the builder stage
COPY --from=builder /tmp/wheels/*.whl /tmp/wheels/

# Install the application package along with all dependencies
RUN pip install /tmp/wheels/*.whl && rm -rf /tmp/wheels

# Copy static and template files
COPY ./static /app/static
COPY ./templates /app/templates

COPY run.py /app/run.py

CMD ["python", "run.py"]
