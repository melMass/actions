# @melmass/free-space

This GitHub Action frees up disk space on GitHub runners by removing unnecessary packages and directories. It's particularly useful for workflows that require additional disk space, such as Docker image builds or large compilation jobs.

## Features

- **Customizable Cleanup**: Choose which package groups and directories to remove
- **Space Tracking**: Reports how much disk space was freed
- **Flexible Configuration**: Add custom packages and directories to remove
- **Output Variables**: Use the freed space information in subsequent steps

## Usage

```yml
- name: Free up disk space
  uses: melMass/actions@free-space
  with:
    # All inputs are optional with sensible defaults
    remove-dotnet: 'true'
    remove-llvm: 'true'
    # Add any custom packages or directories as needed
    custom-packages: 'mono-devel libgl1-mesa-dri'
    custom-directories: '/opt/hostedtoolcache/CodeQL'
```

## Inputs

| Input | Description | Required | Default |
| --- | --- | --- | --- |
| `remove-dotnet` | Remove .NET packages and directories | No | `true` |
| `remove-llvm` | Remove LLVM packages | No | `true` |
| `remove-php` | Remove PHP packages | No | `true` |
| `remove-mongodb` | Remove MongoDB packages | No | `true` |
| `remove-mysql` | Remove MySQL packages | No | `true` |
| `remove-azure-cli` | Remove Azure CLI | No | `true` |
| `remove-browsers` | Remove Chrome and Firefox browsers | No | `true` |
| `remove-android` | Remove Android SDK | No | `true` |
| `remove-haskell` | Remove Haskell/GHC | No | `true` |
| `remove-powershell` | Remove PowerShell | No | `true` |
| `custom-packages` | Additional packages to remove (space-separated) | No | `""` |
| `custom-directories` | Additional directories to remove (space-separated, absolute paths) | No | `""` |

## Outputs

| Output | Description |
| --- | --- |
| `space-freed-kb` | Disk space freed in KB |
| `space-freed-mb` | Disk space freed in MB |
| `space-freed-gb` | Disk space freed in GB (with 2 decimal places) |
| `initial-space` | Initial available disk space |
| `final-space` | Final available disk space |

## Example Workflows

### Basic Usage

```yml
name: Build Docker Image

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Free up disk space
        uses: melMass/actions@free-space
        
      - name: Build Docker image
        run: docker build -t myapp:latest .
```

### Custom Configuration

```yml
name: Build Large Project

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Free up disk space
        id: free-space
        uses: melMass/actions@free-space
        with:
          remove-dotnet: 'true'
          remove-llvm: 'true'
          remove-php: 'true'
          remove-mongodb: 'true'
          remove-mysql: 'true'
          remove-azure-cli: 'true'
          remove-browsers: 'true'
          custom-packages: 'mono-devel libgl1-mesa-dri'
          custom-directories: '/opt/hostedtoolcache/CodeQL'
        
      - name: Show freed space
        run: echo "Freed ${{ steps.free-space.outputs.space-freed-gb }} GB of disk space"
        
      - name: Build project
        run: ./build.sh
```

### Selective Cleanup

```yml
name: Android Build

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Free up disk space (keep Android SDK)
        uses: melMass/actions@free-space
        with:
          remove-android: 'false'  # Keep Android SDK
          remove-dotnet: 'true'
          remove-llvm: 'true'
          remove-php: 'true'
          
      - name: Set up Android SDK
        uses: actions/setup-java@v3
        with:
          distribution: 'temurin'
          java-version: '17'
          
      - name: Build Android app
        run: ./gradlew assembleRelease
```

## How Much Space Can Be Freed?

On a standard GitHub-hosted Ubuntu runner, this action can free up approximately **20-30 GB** of disk space when using the default settings. The exact amount varies depending on the runner image and which components you choose to remove.

## Notes

- This action is designed for Ubuntu runners and may not work on Windows or macOS runners
- Removing packages and directories may affect subsequent steps that depend on them
- Always test your workflow to ensure that removing specific packages doesn't break your build
- The action uses `sudo` to remove packages and directories, which is available on GitHub-hosted runners

## License

MIT
