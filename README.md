# @melmass/sync-fork

This GitHub Action automatically syncs a fork with its upstream repository and manages the pull request process. It's designed to keep your fork up-to-date with minimal manual intervention.

## How It Works

1. **Syncs with Upstream**: Uses GitHub's API to merge upstream changes into your specified branch
2. **Manages Pull Requests**: 
   - If a PR already exists for the branch, it adds a comment with the update information
   - If no PR exists, it creates a new PR to track the changes

This is particularly useful for:
- Maintaining forks of actively developed repositories
- Ensuring your feature branches stay in sync with upstream changes
- Automating the tedious process of keeping forks updated

## Inputs

| Input | Description | Required | Default |
| --- | --- | --- | --- |
| `repo-token` | GitHub token with repository access | Yes | - |
| `feature-branch` | The branch in your fork that you want to update | Yes | - |
| `upstream-branch` | The upstream branch to sync from | Yes | - |

## Example Usage

### Basic Usage

```yml
name: Sync Fork

on:
  schedule:
    - cron: '0 0 * * *'  # Runs daily at midnight
  workflow_dispatch:  # Allows manual triggering

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Sync fork with upstream
        uses: melMass/actions@sync-fork
        with:
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          feature-branch: "main"
          upstream-branch: "main"
```

### Multiple Branches

```yml
name: Sync Fork Branches

on:
  schedule:
    - cron: '0 0 * * *'  # Runs daily at midnight
  workflow_dispatch:

jobs:
  sync-main:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Sync main branch
        uses: melMass/actions@sync-fork
        with:
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          feature-branch: "main"
          upstream-branch: "main"
          
  sync-develop:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Sync develop branch
        uses: melMass/actions@sync-fork
        with:
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          feature-branch: "develop"
          upstream-branch: "develop"
```

## Technical Details

The action uses the GitHub REST API to:
1. Check for existing open PRs for the target branch
2. Merge upstream changes into the target branch
3. Either update an existing PR with a comment or create a new PR

This is all handled automatically without requiring any manual intervention once set up.

## Limitations

- Requires appropriate permissions for the GitHub token
- May encounter conflicts if there are incompatible changes between your fork and the upstream
- Works best when your fork doesn't have significant divergence from the upstream
