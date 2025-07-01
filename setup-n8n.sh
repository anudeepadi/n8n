#!/bin/bash

# Quick start script for n8n on Mac
echo "Setting up n8n on Mac..."

# Create directory
mkdir -p ~/n8n-local
cd ~/n8n-local

# Create local files directory
mkdir -p local-files

# Create simple compose file for local development
cat > compose.yaml << 'EOF'
services:
  n8n:
    image: docker.n8n.io/n8nio/n8n
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=localhost
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - NODE_ENV=development
      - WEBHOOK_URL=http://localhost:5678/
      - GENERIC_TIMEZONE=America/New_York
    volumes:
      - n8n_data:/home/node/.n8n
      - ./local-files:/files

volumes:
  n8n_data:
EOF

# Start n8n
echo "Starting n8n..."
docker compose up -d

echo "n8n is starting up..."
echo "Once ready, access it at: http://localhost:5678"
echo ""
echo "To stop n8n: docker compose stop"
echo "To view logs: docker compose logs -f"