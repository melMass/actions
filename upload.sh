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

# Set up SSH key with proper permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa

# Set up SSH options with maximum compatibility
SSH_OPTIONS="-p $PORT -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -o ServerAliveInterval=60 -o TCPKeepAlive=yes"

# Add debugging if needed
if [ "${INPUT_DEBUG:-false}" = "true" ]; then
  SSH_OPTIONS="$SSH_OPTIONS -v"
fi

echo "SSH options: $SSH_OPTIONS"

# Check if host is reachable
echo "::group::Checking if host is reachable"
echo "Testing connection to $HOST:$PORT..."

# Ensure netcat is installed
if ! command -v nc &> /dev/null; then
  echo "netcat is not installed. Installing..."
  if command -v apt-get &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y netcat
  elif command -v yum &> /dev/null; then
    sudo yum install -y nc
  elif command -v brew &> /dev/null; then
    brew install netcat
  else
    echo "Warning: Could not install netcat. Skipping host reachability check."
  fi
fi

if command -v nc &> /dev/null && ! timeout 15 nc -z -w 5 $HOST $PORT 2>/dev/null; then
  echo "::error::Host $HOST is not reachable on port $PORT"
  echo "This could be due to network issues, firewall rules, or the host being down."
  echo "Please check your network connection and host configuration."
  exit 1
fi

echo "Host $HOST is reachable on port $PORT"
echo "::endgroup::"

# Ensure the destination directory exists
echo "::group::Ensuring destination directory exists"
mkdir -p ~/.ssh/controlmasters
ssh $SSH_OPTIONS -o ControlMaster=auto -o ControlPath=~/.ssh/controlmasters/%r@%h:%p $USERNAME@$HOST "mkdir -p \$(dirname $DESTINATION)" || echo "Could not create destination directory, will try to continue anyway"
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
  
  # Build rsync command with simplified options for maximum compatibility
  RSYNC_CMD="rsync -avz --stats $OPTIONS -e 'ssh $SSH_OPTIONS' $SOURCE $USERNAME@$HOST:$DESTINATION"
  echo "Running: $RSYNC_CMD"
  
  # Run rsync with simple retry logic and proper error handling
  TRANSFER_SUCCESS=false
  for i in {1..3}; do
    echo "Attempt $i of 3"
    eval "$RSYNC_CMD" | tee "$STATS_FILE"
    RSYNC_EXIT_CODE=${PIPESTATUS[0]}
    
    if [ $RSYNC_EXIT_CODE -eq 0 ]; then
      echo "Transfer successful!"
      TRANSFER_SUCCESS=true
      break
    else
      echo "Transfer attempt $i failed with exit code $RSYNC_EXIT_CODE"
      if [ $i -lt 3 ]; then
        echo "Retrying in 3 seconds..."
        sleep 3
      else
        echo "All retry attempts failed."
      fi
    fi
  done
  
  # Exit with error if transfer failed
  if [ "$TRANSFER_SUCCESS" != "true" ]; then
    echo "::error::Failed to transfer files after 3 attempts"
    exit 1
  fi
  
  # Extract statistics
  TRANSFERRED_FILES=$(grep "Number of files transferred" "$STATS_FILE" | awk '{print $5}' || echo "0")
  TRANSFERRED_BYTES=$(grep "Total transferred file size" "$STATS_FILE" | awk '{print $5}' || echo "0")
  
  echo "Files transferred: $TRANSFERRED_FILES"
  echo "Bytes transferred: $TRANSFERRED_BYTES"
  
  echo "::endgroup::"
else
  echo "::group::Uploading files with scp"
  
  # Build scp command with simplified options
  SCP_OPTIONS="-P $PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15"
  
  # Build scp command
  SCP_CMD="scp $SCP_OPTIONS $OPTIONS -r $SOURCE $USERNAME@$HOST:$DESTINATION"
  echo "Running: $SCP_CMD"
  
  # Run scp with simple retry logic and proper error handling
  TRANSFER_SUCCESS=false
  for i in {1..3}; do
    echo "Attempt $i of 3"
    eval "$SCP_CMD"
    SCP_EXIT_CODE=$?
    
    if [ $SCP_EXIT_CODE -eq 0 ]; then
      echo "Transfer successful!"
      TRANSFER_SUCCESS=true
      break
    else
      echo "Transfer attempt $i failed with exit code $SCP_EXIT_CODE"
      if [ $i -lt 3 ]; then
        echo "Retrying in 3 seconds..."
        sleep 3
      else
        echo "All retry attempts failed."
      fi
    fi
  done
  
  # Exit with error if transfer failed
  if [ "$TRANSFER_SUCCESS" != "true" ]; then
    echo "::error::Failed to transfer files after 3 attempts"
    exit 1
  fi
  
  # Since scp doesn't provide statistics, we'll estimate
  TRANSFERRED_FILES="1"
  TRANSFERRED_BYTES="0"
  
  echo "::endgroup::"
fi

# Run post-upload commands if specified
if [ -n "$POST_COMMANDS" ]; then
  echo "::group::Running post-upload commands"
  echo "Commands to execute: $POST_COMMANDS"
  
  # Create a script file with all commands
  REMOTE_SCRIPT="/tmp/remote_commands_$$.sh"
  echo "#!/bin/bash" > "$REMOTE_SCRIPT"
  echo "set -e" >> "$REMOTE_SCRIPT"
  echo "$POST_COMMANDS" >> "$REMOTE_SCRIPT"
  chmod +x "$REMOTE_SCRIPT"
  
  # Copy script to remote server
  echo "Copying command script to remote server"
  scp -P $PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 "$REMOTE_SCRIPT" "$USERNAME@$HOST:/tmp/remote_commands.sh" || {
    echo "Failed to copy script to remote server"
    cat "$REMOTE_SCRIPT"
    echo "Will try to run commands directly"
    
    # Fallback to direct command execution
    ssh $SSH_OPTIONS "$USERNAME@$HOST" "$POST_COMMANDS" || echo "Warning: Post-commands execution failed"
  }
  
  # Execute script on remote server
  echo "Executing command script on remote server"
  ssh $SSH_OPTIONS "$USERNAME@$HOST" "bash /tmp/remote_commands.sh" || echo "Warning: Script execution failed"
  
  # Clean up
  rm -f "$REMOTE_SCRIPT"
  
  echo "::endgroup::"
fi

# Set outputs
echo "status=success" > "$GITHUB_OUTPUT"
echo "transferred-files=$TRANSFERRED_FILES" >> "$GITHUB_OUTPUT"
echo "transferred-bytes=$TRANSFERRED_BYTES" >> "$GITHUB_OUTPUT"

# Clean up
rm -f "$STATS_FILE"

echo "Upload completed successfully!"
