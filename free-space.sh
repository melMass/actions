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

# List largest packages for information
echo "Listing 100 largest packages"
dpkg-query -Wf '${Installed-Size}\t${Package}\n' | sort -n | tail -n 100 || echo "Could not list packages"

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

# Remove package groups
echo "Removing large package groups"
for pkg in "${PACKAGES_TO_CHECK[@]}"; do
  echo "Checking for packages matching ^$pkg.*"
  if apt list --installed 2>/dev/null | grep -q "^$pkg"; then
    echo "Removing $pkg packages"
    sudo apt-get remove -y "^$pkg.*" || echo "Some $pkg packages could not be removed"
  else
    echo "No $pkg packages found"
  fi
done

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

# Remove individual packages
echo "Removing individual packages"
for pkg in "${INDIVIDUAL_PACKAGES[@]}"; do
  if dpkg -l | grep -q "\b$pkg\b"; then
    echo "Removing $pkg"
    sudo apt-get remove -y "$pkg" || echo "Could not remove $pkg"
  else
    echo "Package $pkg is not installed"
  fi
done

# Clean up
sudo apt-get autoremove -y
sudo apt-get clean

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

# Remove directories
echo "Removing large directories"
for dir in "${DIRECTORIES[@]}"; do
  if [ -d "$dir" ]; then
    echo "Removing directory: $dir"
    sudo rm -rf "$dir"
  else
    echo "Directory does not exist: $dir"
  fi
done

# Record final disk space
echo "Final disk space:"
FINAL_SPACE=$(df -h / | grep -v Filesystem | awk '{print $4}')
FINAL_SPACE_KB=$(df -k / | grep -v Filesystem | awk '{print $4}')
echo "Available space: $FINAL_SPACE"

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
