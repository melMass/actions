# Use an official Rust image as a parent image for building NuShell
FROM rust:latest

# Install NuShell
RUN cargo install nu

# Set the working directory
WORKDIR /action

# Copy the entrypoint script
COPY entrypoint.nu /action/entrypoint.nu
COPY toolkit.nu /action/toolkit.nu

# Make sure your entrypoint script is executable
RUN chmod +x /action/entrypoint.nu

# Set the Docker container's entrypoint
ENTRYPOINT ["/action/entrypoint.nu"]
