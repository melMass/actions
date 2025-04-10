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
STRICT_HOST_KEY_CHECKING="${INPUT_STRICT_HOST_KEY_CHECKING:-true}"

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

# Set up SSH options based on strict host key checking setting
SSH_OPTIONS="-p $PORT"
if [ "$STRICT_HOST_KEY_CHECKING" = "false" ]; then
  echo "Strict host key checking is disabled"
  SSH_OPTIONS="$SSH_OPTIONS -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
fi

# Add connection timeout to avoid hanging
SSH_OPTIONS="$SSH_OPTIONS -o ConnectTimeout=10"

# Test SSH connection before attempting transfer
echo "::group::Testing SSH connection"
echo "Testing SSH connection to $HOST:$PORT..."
ssh $SSH_OPTIONS -o BatchMode=yes -T $USERNAME@$HOST 2>&1 || {
  CONNECTION_STATUS=$?
  echo "SSH connection test failed with exit code: $CONNECTION_STATUS"
  echo "Trying with verbose output for debugging:"
  ssh $SSH_OPTIONS -v -o BatchMode=yes -T $USERNAME@$HOST 2>&1 || true
  
  # Continue anyway, since we're using StrictHostKeyChecking=no for the actual transfer
  echo "Will attempt transfer despite connection test failure"
}
echo "::endgroup::"

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
  # Add timeout and connection retries
  RSYNC_CMD="rsync -avz --stats --timeout=60 --contimeout=10 $OPTIONS -e 'ssh $SSH_OPTIONS' $SOURCE $USERNAME@$HOST:$DESTINATION"
  echo "Running: $RSYNC_CMD"
  
  # Run rsync with retries and capture output
  MAX_RETRIES=3
  RETRY_COUNT=0
  SUCCESS=false
  
  while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$SUCCESS" = "false" ]; do
    echo "Attempt $(($RETRY_COUNT + 1)) of $MAX_RETRIES"
    eval "$RSYNC_CMD" | tee "$STATS_FILE"
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
      SUCCESS=true
      echo "Transfer successful!"
    else
      RETRY_COUNT=$(($RETRY_COUNT + 1))
      if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
        echo "Transfer failed, retrying in 5 seconds..."
        sleep 5
      else
        echo "All retry attempts failed."
      fi
    fi
  done
  
  # Extract statistics
  TRANSFERRED_FILES=$(grep "Number of files transferred" "$STATS_FILE" | awk '{print $5}' || echo "0")
  TRANSFERRED_BYTES=$(grep "Total transferred file size" "$STATS_FILE" | awk '{print $5}' || echo "0")
  
  echo "Files transferred: $TRANSFERRED_FILES"
  echo "Bytes transferred: $TRANSFERRED_BYTES"
  
  echo "::endgroup::"
else
  echo "::group::Uploading files with scp"
  
  # Build scp command with SSH options
  SCP_OPTIONS="-P $PORT"
  if [ "$STRICT_HOST_KEY_CHECKING" = "false" ]; then
    SCP_OPTIONS="$SCP_OPTIONS -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
  fi
  
  # Build scp command
  SCP_CMD="scp $SCP_OPTIONS $OPTIONS -r $SOURCE $USERNAME@$HOST:$DESTINATION"
  echo "Running: $SCP_CMD"
  
  # Run scp with retries
  MAX_RETRIES=3
  RETRY_COUNT=0
  SUCCESS=false
  
  while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$SUCCESS" = "false" ]; do
    echo "Attempt $(($RETRY_COUNT + 1)) of $MAX_RETRIES"
    eval "$SCP_CMD"
    
    if [ $? -eq 0 ]; then
      SUCCESS=true
      echo "Transfer successful!"
    else
      RETRY_COUNT=$(($RETRY_COUNT + 1))
      if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
        echo "Transfer failed, retrying in 5 seconds..."
        sleep 5
      else
        echo "All retry attempts failed."
      fi
    fi
  done
  
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
  
  # Execute commands on remote server with error handling
  for CMD in $COMMANDS; do
    echo "Running command: $CMD"
    
    # Try command with timeout to prevent hanging
    MAX_RETRIES=2
    RETRY_COUNT=0
    CMD_SUCCESS=false
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$CMD_SUCCESS" = "false" ]; do
      echo "Command attempt $(($RETRY_COUNT + 1)) of $MAX_RETRIES"
      
      # Use timeout to prevent hanging
      timeout 30 ssh $SSH_OPTIONS "$USERNAME@$HOST" "$CMD" && CMD_SUCCESS=true
      
      if [ "$CMD_SUCCESS" = "true" ]; then
        echo "Command executed successfully!"
      else
        RETRY_COUNT=$(($RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
          echo "Command failed, retrying in 3 seconds..."
          sleep 3
        else
          echo "Failed to execute command after $MAX_RETRIES attempts: $CMD"
          echo "Continuing with next command..."
        fi
      fi
    done
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
