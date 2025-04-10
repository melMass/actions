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
STRICT_HOST_KEY_CHECKING="${INPUT_STRICT_HOST_KEY_CHECKING:-false}"
PRIVATE_KEY="${INPUT_PRIVATE_KEY}"

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
[ -z "$PRIVATE_KEY" ] && error_exit "Private key is required"

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

# Set up SSH key
echo "::group::Setting up SSH key"
echo "Setting up SSH keys..."

# Create SSH directory with proper permissions
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Write private key with proper error handling
echo "Writing private key..."
# Ensure the key is properly formatted with newlines
echo "$PRIVATE_KEY" | sed 's/\\n/\n/g' > ~/.ssh/id_rsa

# Check if the key looks valid
if ! grep -q "BEGIN" ~/.ssh/id_rsa; then
  echo "WARNING: Private key doesn't contain 'BEGIN' line, it might be malformed"
  echo "First few characters of the key:"
  head -c 20 ~/.ssh/id_rsa
  error_exit "Invalid SSH key format"
fi

# Set proper permissions
echo "Setting permissions..."
chmod 600 ~/.ssh/id_rsa

# Add host to known hosts
echo "Adding host to known_hosts..."
echo "Host: $HOST, Port: $PORT"

# Try to resolve the hostname first
echo "Resolving hostname..."
getent hosts $HOST || echo "Warning: Could not resolve hostname"

# Try with timeout to avoid hanging
echo "Running ssh-keyscan..."
timeout 10 ssh-keyscan -p $PORT -H $HOST > ~/.ssh/known_hosts || echo "Warning: ssh-keyscan timed out"

# Check if known_hosts was created and has content
if [ ! -s ~/.ssh/known_hosts ]; then
  echo "Warning: known_hosts file is empty, adding a manual entry"
  # Add a manual entry to bypass host checking
  echo "$HOST ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==" >> ~/.ssh/known_hosts
fi

cat ~/.ssh/known_hosts

# Verify setup
echo "Verifying SSH setup..."
ls -la ~/.ssh
echo "::endgroup::"

# Set up SSH options with maximum compatibility
SSH_OPTIONS="-p $PORT -o BatchMode=yes -o ConnectTimeout=15 -o ServerAliveInterval=60 -o TCPKeepAlive=yes"

# Handle strict host key checking
if [ "$STRICT_HOST_KEY_CHECKING" = "true" ]; then
  echo "Enabling strict host key checking"
  SSH_OPTIONS="$SSH_OPTIONS -o StrictHostKeyChecking=yes"
else
  echo "Disabling strict host key checking"
  SSH_OPTIONS="$SSH_OPTIONS -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
fi

# Add debugging if needed
if [ "${INPUT_DEBUG:-false}" = "true" ]; then
  echo "Enabling verbose SSH debugging"
  SSH_OPTIONS="$SSH_OPTIONS -v"
fi

echo "SSH options: $SSH_OPTIONS"

# Test SSH connection before proceeding
echo "::group::Testing SSH connection"
echo "Testing SSH connection to $USERNAME@$HOST:$PORT..."

# Try to connect with a simple command
if ! ssh $SSH_OPTIONS $USERNAME@$HOST "echo 'Connection successful'" 2>/dev/null; then
  echo "::error::Failed to establish SSH connection to $HOST"
  echo "This could be due to authentication issues, firewall rules, or incorrect credentials."
  echo "Please verify your SSH key and connection settings."
  exit 1
fi

echo "SSH connection successful!"
echo "::endgroup::"

# Check if host is reachable first (faster check before attempting SSH)
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
  
  # Create a script file with all commands and better error handling
  REMOTE_SCRIPT="/tmp/remote_commands_$$.sh"
  cat > "$REMOTE_SCRIPT" << EOF
#!/bin/bash
set -e

# Function to log errors
log_error() {
  echo "ERROR: \$1" >&2
  exit 1
}

# Change to destination directory
cd "$DESTINATION" || log_error "Failed to change directory to $DESTINATION"

echo "Executing commands in \$(pwd)..."

# Run the commands
{
$POST_COMMANDS
} || {
  EXIT_CODE=\$?
  log_error "Command failed with exit code \$EXIT_CODE"
}

echo "Commands completed successfully"
EOF

  chmod +x "$REMOTE_SCRIPT"
  
  # Prepare SCP options with the same settings as SSH
  SCP_OPTIONS="-P $PORT"
  
  # Add the same SSH options to SCP
  if [[ "$SSH_OPTIONS" =~ StrictHostKeyChecking=no ]]; then
    SCP_OPTIONS="$SCP_OPTIONS -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
  fi
  
  if [[ "$SSH_OPTIONS" =~ ConnectTimeout=([0-9]+) ]]; then
    SCP_OPTIONS="$SCP_OPTIONS -o ConnectTimeout=${BASH_REMATCH[1]}"
  fi
  
  if [ "${INPUT_DEBUG:-false}" = "true" ]; then
    SCP_OPTIONS="$SCP_OPTIONS -v"
  fi
  
  echo "SCP options: $SCP_OPTIONS"
  
  # Copy script to remote server with retry logic
  echo "Copying command script to remote server"
  SCP_SUCCESS=false
  for i in {1..3}; do
    echo "SCP attempt $i of 3"
    if scp $SCP_OPTIONS "$REMOTE_SCRIPT" "$USERNAME@$HOST:/tmp/remote_commands.sh"; then
      echo "Script copied successfully"
      SCP_SUCCESS=true
      break
    else
      echo "SCP attempt $i failed"
      if [ $i -lt 3 ]; then
        echo "Retrying in 3 seconds..."
        sleep 3
      else
        echo "All SCP retry attempts failed."
      fi
    fi
  done
  
  # Execute commands based on script copy success
  if [ "$SCP_SUCCESS" = "true" ]; then
    # Execute script on remote server
    echo "Executing command script on remote server"
    if ssh $SSH_OPTIONS "$USERNAME@$HOST" "bash /tmp/remote_commands.sh"; then
      echo "Remote script executed successfully"
    else
      SSH_EXIT_CODE=$?
      echo "::warning::Script execution failed with exit code $SSH_EXIT_CODE"
      echo "This may indicate an issue with the post-commands or the remote environment."
      # Don't exit here, we still want to report the transfer as successful
    fi
    
    # Clean up remote script
    ssh $SSH_OPTIONS "$USERNAME@$HOST" "rm -f /tmp/remote_commands.sh" || echo "Failed to remove remote script"
  else
    echo "::warning::Failed to copy script to remote server. Trying direct command execution..."
    # Fallback to direct command execution
    if ssh $SSH_OPTIONS "$USERNAME@$HOST" "cd $DESTINATION && { $POST_COMMANDS; }"; then
      echo "Direct command execution successful"
    else
      echo "::warning::Direct command execution failed"
    fi
  fi
  
  # Clean up local script
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
