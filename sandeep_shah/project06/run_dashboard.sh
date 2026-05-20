#!/bin/bash
set -e

IMAGE_NAME="bpd-homicide-dashboard"
CONTAINER_NAME="bpd-dashboard"
PORT=3838

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   Baltimore City Police Department                   ║"
echo "║   Homicide Analysis Dashboard — Launcher             ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

echo "⏹  Stopping any existing container..."
docker stop $CONTAINER_NAME 2>/dev/null || true
docker rm   $CONTAINER_NAME 2>/dev/null || true

echo "🔨 Building Docker image..."
docker build -t $IMAGE_NAME .

echo ""
echo "🚀 Starting dashboard container..."
docker run -d \
    --name $CONTAINER_NAME \
    -p $PORT:3838 \
    $IMAGE_NAME

echo "⏳ Waiting for Shiny server to start (30 seconds)..."
sleep 30

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  ✅ Dashboard is LIVE!                               ║"
echo "║                                                      ║"
echo "║  👉 Open your browser and go to:                     ║"
echo "║     http://localhost:3838/bpd/                       ║"
echo "║                                                      ║"
echo "║  To stop:  docker stop bpd-dashboard                 ║"
echo "║  To logs:  docker logs bpd-dashboard                 ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
