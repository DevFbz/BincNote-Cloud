#!/usr/bin/env bash
set -x
set -eo pipefail

cd "$(dirname "$0")/.."

# Check if .env file exists in the current directory
if [ -f ".env" ]; then
  echo ".env file exists"
else
  echo ".env file does not exist. Please copy deploy.env to .env and update the values."
  exit 1  # Exit with an error code to indicate failure
fi

IMAGE_VERSION="${1:-latest}"  # Default to 'latest' if no argument is provided


# Stop and remove running containers
docker ps -q --filter "network=bincnote-cloud_default" | xargs -r docker stop
docker ps -aq --filter "network=bincnote-cloud_default" | xargs -r docker rm
docker compose down

# Build amd64 images with a new local tag
# Before running following command, make sure you have the .env file with the correct values
# For example: SKIP_BUILD=true  ./script/run_ci_server.sh 0.6.51-amd64
if [[ -z "${SKIP_BUILD+x}" ]]; then
  docker build --platform=linux/amd64 -t bincnoteinc/bincnote_cloud_local:$IMAGE_VERSION -f Dockerfile .
  docker build --platform=linux/amd64 -t bincnoteinc/bincnote_worker_local:$IMAGE_VERSION -f ./services/bincnote-worker/Dockerfile .
  
  cat > docker-compose.override.yml <<EOF
version: '3'
services:
  bincnote_cloud:
    image: bincnoteinc/bincnote_cloud:$IMAGE_VERSION
  bincnote_worker:
    image: bincnoteinc/bincnote_worker:$IMAGE_VERSION
EOF


  export RUST_LOG=trace
  docker compose -f docker-compose-ci.yml -f docker-compose.override.yml up -d --build
  rm docker-compose.override.yml
else
  echo "Skipping the build process for bincnote services..."
  echo "Using image version: $IMAGE_VERSION"

  # Set the image version to the input value
  export RUST_LOG=trace
  export APPFLOWY_CLOUD_VERSION=$IMAGE_VERSION
  export APPFLOWY_WORKER_VERSION=$IMAGE_VERSION
  export APPFLOWY_ADMIN_FRONTEND_VERSION=$IMAGE_VERSION
  docker compose -f docker-compose-ci.yml pull

  echo "Printing the bincnote_cloud image version:"
  docker images bincnoteinc/bincnote_cloud --format "{{.Repository}}:{{.Tag}} (Created: {{.CreatedSince}}, Size: {{.Size}})"

  docker compose -f docker-compose-ci.yml up -d
fi