# Multi-stage build for USB Music Player
# Stage 1: Build React frontend
FROM node:16-alpine AS frontend-builder

WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci --only=production

COPY frontend/ ./
RUN npm run build

# Stage 2: Python backend with system dependencies
FROM python:3.9-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    vlc \
    vlc-plugin-base \
    alsa-utils \
    pulseaudio \
    udev \
    usbutils \
    exfat-fuse \
    exfatprogs \
    sudo \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd -m -s /bin/bash appuser && \
    usermod -aG audio,plugdev appuser

# Set working directory
WORKDIR /app

# Copy Python requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy Python application files
COPY *.py ./
COPY utils.py ./

# Copy built frontend from previous stage
COPY --from=frontend-builder /app/frontend/build ./frontend/build

# Create necessary directories for USB mounts
RUN mkdir -p /media/pi/MUSIC /media/pi/PLAY_CARD && \
    chown -R appuser:appuser /media/pi /app

# Create config directory
RUN mkdir -p /app/config && chown appuser:appuser /app/config

# Switch to app user
USER appuser

# Expose Flask port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Start the application
CMD ["python", "main.py"] 