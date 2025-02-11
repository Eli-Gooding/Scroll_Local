#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: ./describe_video.sh <path_to_video>"
    exit 1
fi

# Get the current directory
CURRENT_DIR=$(pwd)

# Get just the filename from the path
VIDEO_FILE=$(basename "$1")

# Ensure the video exists in the current directory
if [ ! -f "$1" ]; then
    echo "Error: Video file not found: $1"
    exit 1
fi

docker run -v "${CURRENT_DIR}:/videos" \
    --env-file .env \
    video-describer "/videos/${VIDEO_FILE}" 