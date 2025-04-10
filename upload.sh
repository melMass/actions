#!/bin/bash

# Enable verbose output for debugging
set -ex

# Get inputs from environment variables
HOST="${INPUT_HOST}"
USERNAME="${INPUT_USERNAME}"
PORT="${INPUT_PORT:-22}"
SOURCE="${INPUT_SOURCE}"
DESTINATION="${INPUT_DESTINATION}"
USE_RSYNC="${INPUT_RSYNC:-true}"
OPTIONS="${INPUT_OPTIONS}"
POST_COMMANDS="${INPUT_POST_COMMANDS}"

# Set default status
echo "status=failure" > "$GITHUB_OUTPUT"
echo "transferred-files=0" >> "$GITHUB_OUTPUT"
echo "transferred-bytes=0" >> "$GITHUB_OUTPUT"

# Function to display error message and exit
error_exit() {
  echo "::error::$1"
  exit 1
}

# Check required inputs
[ -z "$HOST" ] && error_exit "Host is required"
[ -z "$USERNAME" ] && error_exit "Username is required"
[ -z "$SOURCE" ] && error_exit "Source path is required"
[ -z "$DESTINATION" ] && error_exit "Destination path is required"

echo "::group::Upload Configuration"
echo "Host: $HOST"
echo "Username: $USERNAME"
echo "Port: $PORT"
echo "Source: $SOURCE"
echo "Destination: $DESTINATION"
echo "Using rsync: $USE_RSYNC"
echo "::endgroup::"

# Create a temporary file for transfer statistics
STATS_FILE=$(mktemp)

# Upload files
if [ "$USE_RSYNC" = "true" ]; then
  echo "::group::Uploading files with rsync"
  
  # Check if rsync is installed
  if ! command -v rsync &> /dev/null; then
    echo "rsync is not installed. Installing..."
    if command -v apt-get &> /dev/null; then
      sudo apt-get update && sudo apt-get install -y rsync
    elif command -v yum &> /dev/null; then
      sudo yum install -y rsync
    elif command -v brew &> /dev/null; then
      brew install rsync
    else
      error_exit "Cannot install rsync. Please install it manually."
    fi
  fi
  
  # Build rsync command with stats output
  RSYNC_CMD="rsync -avz --stats $OPTIONS -e 'ssh -p $PORT' $SOURCE $USERNAME@$HOST:$DESTINATION"
  echo "Running: $RSYNC_CMD"
  
  # Run rsync and capture output
  eval "$RSYNC_CMD" | tee "$STATS_FILE"
  
  # Extract statistics
  TRANSFERRED_FILES=$(grep "Number of files transferred" "$STATS_FILE" | awk '{print $5}')
  TRANSFERRED_BYTES=$(grep "Total transferred file size" "$STATS_FILE" | awk '{print $5}')
  
  echo "Files transferred: $TRANSFERRED_FILES"
  echo "Bytes transferred: $TRANSFERRED_BYTES"
  
  echo "::endgroup::"
else
  echo "::group::Uploading files with scp"
  
  # Build scp command
  SCP_CMD="scp -P $PORT $OPTIONS -r $SOURCE $USERNAME@$HOST:$DESTINATION"
  echo "Running: $SCP_CMD"
  
  # Run scp
  eval "$SCP_CMD"
  
  # Since scp doesn't provide statistics, we'll estimate
  TRANSFERRED_FILES="1"
  TRANSFERRED_BYTES="0"
  
  echo "::endgroup::"
fi

# Run post-upload commands if specified
if [ -n "$POST_COMMANDS" ]; then
  echo "::group::Running post-upload commands"
  
  # Replace semicolons with newlines for better logging
  COMMANDS=$(echo "$POST_COMMANDS" | tr ';' '\n')
  
  # Execute commands on remote server
  for CMD in $COMMANDS; do
    echo "Running command: $CMD"
    ssh -p "$PORT" "$USERNAME@$HOST" "$CMD"
  done
  
  echo "::endgroup::"
fi

# Set outputs
echo "status=success" > "$GITHUB_OUTPUT"
echo "transferred-files=$TRANSFERRED_FILES" >> "$GITHUB_OUTPUT"
echo "transferred-bytes=$TRANSFERRED_BYTES" >> "$GITHUB_OUTPUT"

# Clean up
rm -f "$STATS_FILE"

echo "Upload completed successfully!"
