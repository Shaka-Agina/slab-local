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

# Create app user with same UID/GID as pi user (1000:1000)
# This ensures proper permissions for USB mounts
RUN groupadd -g 1000 pi && \
    useradd -m -u 1000 -g 1000 -s /bin/bash pi && \
    usermod -aG audio,plugdev pi

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

# Create necessary directories structure (USB mounts will be handled by host system)
RUN mkdir -p /media/pi && \
    chown -R pi:pi /media/pi /app

# Create config directory
RUN mkdir -p /app/config && chown pi:pi /app/config

# Switch to pi user
USER pi

# Expose Flask port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Start the application
CMD ["python", "main.py"] 