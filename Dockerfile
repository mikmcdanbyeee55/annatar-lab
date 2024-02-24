# --- Final Stage ---
FROM python:3.11-slim as final

ENV BUILD_VERSION=${BUILD_VERSION}

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DB_PATH=/app/data/annatar.db
ENV NUM_WORKERS 4

VOLUME /app/data
WORKDIR /app

# Install procps to provide ps command
RUN apt-get update \
    && apt-get install -y procps \
    && rm -rf /var/lib/apt/lists/*

# Copy wheels and built wheel from the builder stage
COPY --from=builder /app/dist/*.whl /tmp/wheels/
COPY --from=builder /tmp/wheels/*.whl /tmp/wheels/

# # Install the application package along with all dependencies
RUN pip install /tmp/wheels/*.whl && rm -rf /tmp/wheels

# # Copy static and template files
COPY ./static /app/static
COPY ./templates /app/templates

COPY run.py /app/run.py

# Install PM2
RUN npm install pm2 -g

# Use PM2 to start your application
CMD ["pm2-runtime", "--interpreter", "python", "run.py"]
