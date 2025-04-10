#!/bin/bash
set -e

echo "=============================================================================="
echo "Freeing up disk space on GitHub runner"
echo "=============================================================================="

# Record initial disk space
echo "Initial disk space:"
INITIAL_SPACE=$(df -h / | grep -v Filesystem | awk '{print $4}')
INITIAL_SPACE_KB=$(df -k / | grep -v Filesystem | awk '{print $4}')
echo "Available space: $INITIAL_SPACE"

# List largest packages for information (run in background)
echo "Listing 100 largest packages (in background)"
{
  dpkg-query -Wf '${Installed-Size}\t${Package}\n' | sort -n | tail -n 100 > /tmp/largest_packages.txt || echo "Could not list packages" > /tmp/largest_packages.txt
  echo "\nLargest packages:" 
  cat /tmp/largest_packages.txt
} &
PACKAGE_LISTING_PID=$!

# Define package groups to remove based on inputs
PACKAGES_TO_CHECK=()
if [ "$INPUT_REMOVE_DOTNET" = "true" ]; then
  PACKAGES_TO_CHECK+=("dotnet")
fi
if [ "$INPUT_REMOVE_LLVM" = "true" ]; then
  PACKAGES_TO_CHECK+=("llvm")
fi
if [ "$INPUT_REMOVE_PHP" = "true" ]; then
  PACKAGES_TO_CHECK+=("php")
fi
if [ "$INPUT_REMOVE_MONGODB" = "true" ]; then
  PACKAGES_TO_CHECK+=("mongodb")
fi
if [ "$INPUT_REMOVE_MYSQL" = "true" ]; then
  PACKAGES_TO_CHECK+=("mysql")
fi

# Remove package groups in parallel
echo "Removing large package groups"
PKGS_TO_REMOVE=()
for pkg in "${PACKAGES_TO_CHECK[@]}"; do
  echo "Checking for packages matching ^$pkg.*"
  if apt list --installed 2>/dev/null | grep -q "^$pkg"; then
    echo "Found $pkg packages to remove"
    PKGS_TO_REMOVE+=("^$pkg.*")
  else
    echo "No $pkg packages found"
  fi
done

# If we have packages to remove, do it in one batch
if [ ${#PKGS_TO_REMOVE[@]} -gt 0 ]; then
  echo "Removing ${#PKGS_TO_REMOVE[@]} package groups in one batch"
  sudo apt-get remove -y ${PKGS_TO_REMOVE[@]} || echo "Some packages could not be removed"
fi

# Define individual packages to remove based on inputs
INDIVIDUAL_PACKAGES=()
if [ "$INPUT_REMOVE_AZURE_CLI" = "true" ]; then
  INDIVIDUAL_PACKAGES+=("azure-cli")
fi
if [ "$INPUT_REMOVE_BROWSERS" = "true" ]; then
  INDIVIDUAL_PACKAGES+=("google-chrome-stable" "firefox")
fi
if [ "$INPUT_REMOVE_POWERSHELL" = "true" ]; then
  INDIVIDUAL_PACKAGES+=("powershell")
fi

# Add custom packages if specified
if [ -n "$INPUT_CUSTOM_PACKAGES" ]; then
  IFS=' ' read -ra CUSTOM_PKGS <<< "$INPUT_CUSTOM_PACKAGES"
  for pkg in "${CUSTOM_PKGS[@]}"; do
    INDIVIDUAL_PACKAGES+=("$pkg")
  done
fi

# Remove individual packages in one batch
echo "Removing individual packages"
PKGS_TO_REMOVE=()
for pkg in "${INDIVIDUAL_PACKAGES[@]}"; do
  if dpkg -l | grep -q "\b$pkg\b"; then
    echo "Found package $pkg to remove"
    PKGS_TO_REMOVE+=("$pkg")
  else
    echo "Package $pkg is not installed"
  fi
done

# If we have packages to remove, do it in one batch
if [ ${#PKGS_TO_REMOVE[@]} -gt 0 ]; then
  echo "Removing ${#PKGS_TO_REMOVE[@]} individual packages in one batch"
  sudo apt-get remove -y ${PKGS_TO_REMOVE[@]} || echo "Some packages could not be removed"
fi

# Clean up - run these in parallel
echo "Running cleanup operations"
{
  sudo apt-get autoremove -y
} &
{
  sudo apt-get clean
} &
wait

# Define directories to remove based on inputs
DIRECTORIES=()
if [ "$INPUT_REMOVE_DOTNET" = "true" ]; then
  DIRECTORIES+=("/usr/share/dotnet")
fi
if [ "$INPUT_REMOVE_HASKELL" = "true" ]; then
  DIRECTORIES+=("/opt/ghc" "/usr/local/.ghcup/")
fi
if [ "$INPUT_REMOVE_ANDROID" = "true" ]; then
  DIRECTORIES+=("/usr/local/lib/android")
fi
if [ "$INPUT_REMOVE_POWERSHELL" = "true" ]; then
  DIRECTORIES+=("/usr/local/share/powershell")
fi
if [ "$INPUT_REMOVE_BROWSERS" = "true" ]; then
  DIRECTORIES+=("/usr/local/share/chromium")
fi

# Standard directories to remove
DIRECTORIES+=(
  "/usr/local/share/boost"
  "$AGENT_TOOLSDIRECTORY"
  "/usr/local/graalvm/"
  "/usr/local/lib/node_modules"
)

# Add custom directories if specified
if [ -n "$INPUT_CUSTOM_DIRECTORIES" ]; then
  IFS=' ' read -ra CUSTOM_DIRS <<< "$INPUT_CUSTOM_DIRECTORIES"
  for dir in "${CUSTOM_DIRS[@]}"; do
    DIRECTORIES+=("$dir")
  done
fi

# Remove directories in parallel
echo "Removing large directories"
remove_dir() {
  local dir="$1"
  if [ -d "$dir" ]; then
    echo "Removing directory: $dir"
    sudo rm -rf "$dir"
    return 0
  else
    echo "Directory does not exist: $dir"
    return 1
  fi
}

# Use background processes with a maximum of 5 concurrent jobs
MAX_JOBS=5
active_jobs=0

for dir in "${DIRECTORIES[@]}"; do
  # Wait if we've reached the maximum number of concurrent jobs
  if [ $active_jobs -ge $MAX_JOBS ]; then
    wait -n
    active_jobs=$((active_jobs - 1))
  fi
  
  # Start a new background job
  remove_dir "$dir" &
  active_jobs=$((active_jobs + 1))
done

# Wait for all remaining jobs to complete
wait

# Record final disk space
echo "Final disk space:"
FINAL_SPACE=$(df -h / | grep -v Filesystem | awk '{print $4}')
FINAL_SPACE_KB=$(df -k / | grep -v Filesystem | awk '{print $4}')
echo "Available space: $FINAL_SPACE"

# Wait for package listing to complete if it's still running
if ps -p $PACKAGE_LISTING_PID > /dev/null 2>&1; then
  echo "Waiting for package listing to complete..."
  wait $PACKAGE_LISTING_PID
fi

# Calculate space saved
echo "Calculating space saved..."
INITIAL_KB=$(echo "$INITIAL_SPACE_KB" | sed 's/[^0-9]*//g')
FINAL_KB=$(echo "$FINAL_SPACE_KB" | sed 's/[^0-9]*//g')

if [ "$FINAL_KB" -gt "$INITIAL_KB" ]; then
  SAVED_KB=$((FINAL_KB - INITIAL_KB))
  SAVED_MB=$((SAVED_KB / 1024))
  SAVED_GB=$(echo "scale=2; $SAVED_KB/1048576" | bc)
else
  SAVED_KB=0
  SAVED_MB=0
  SAVED_GB="0.00"
fi

# Set outputs
echo "space-freed-kb=$SAVED_KB" >> $GITHUB_OUTPUT
echo "space-freed-mb=$SAVED_MB" >> $GITHUB_OUTPUT
echo "space-freed-gb=$SAVED_GB" >> $GITHUB_OUTPUT
echo "initial-space=$INITIAL_SPACE" >> $GITHUB_OUTPUT
echo "final-space=$FINAL_SPACE" >> $GITHUB_OUTPUT

# Print summary
echo "=============================================================================="
echo "Space saved: $SAVED_MB MB ($SAVED_GB GB)"
echo "Initial available space: $INITIAL_SPACE"
echo "Final available space: $FINAL_SPACE"
echo "=============================================================================="
