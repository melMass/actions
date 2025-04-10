# @melmass/sync-fork

This GitHub Action automatically syncs branches between repositories and manages the pull request process. It's designed for two main use cases:

1. **Fork Synchronization**: Keep your fork up-to-date with its upstream repository
2. **Branch PRs**: Create and maintain pull requests between branches in the same repository

## How It Works

### Mode 1: Fork Synchronization
When used without the `upstream-repo` parameter:
1. **Syncs with Upstream**: Uses GitHub's `mergeUpstream` API to merge changes from the upstream repository into your fork
2. **Manages Pull Requests**: Updates existing PRs or creates new ones to track changes

### Mode 2: Branch PRs
When used with the `upstream-repo` parameter or `base-branch` parameter:
1. **Syncs Branches**: Updates your feature branch with changes from another repository or branch
2. **Creates/Updates PRs**: Maintains pull requests between branches (e.g., dev → main)

This action is particularly useful for:
- Maintaining forks of actively developed repositories
- Automating the creation of PRs from development branches to main
- Keeping feature branches in sync with the main branch
- Setting up automated workflows between repositories

## Inputs

| Input | Description | Required | Default |
| --- | --- | --- | --- |
| `repo-token` | GitHub token with repository access | Yes | - |
| `feature-branch` | The branch you want to update | Yes | - |
| `upstream-branch` | The branch to sync from | Yes | - |
| `upstream-repo` | The upstream repository in format 'owner/repo' | No | Uses the repository's upstream if it's a fork |
| `base-branch` | The base branch for the PR | No | Same as feature-branch (for forks) or repo default branch (for branch PRs) |

## Example Usage

### Mode 1: Fork Synchronization

```yml
name: Sync Fork with Upstream

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

### Mode 2: Branch PRs (Same Repository)

```yml
name: Create PR from Dev to Main

on:
  push:
    branches:
      - dev
  schedule:
    - cron: '0 0 * * *'  # Runs daily at midnight
  workflow_dispatch:

jobs:
  create-pr:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Create/Update PR from dev to main
        uses: melMass/actions@sync-fork
        with:
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          feature-branch: "dev"      # Source branch
          base-branch: "main"        # Target branch for PR
          upstream-branch: "dev"     # Same as feature-branch in this case
```

### Mode 2: Sync from External Repository

```yml
name: Sync from External Repository

on:
  schedule:
    - cron: '0 0 * * *'  # Runs daily at midnight
  workflow_dispatch:

jobs:
  sync-from-external:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Sync from external repository
        uses: melMass/actions@sync-fork
        with:
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          feature-branch: "imported-feature"   # Local branch to update
          upstream-repo: "otherorg/repo"       # External repository
          upstream-branch: "feature"           # Branch in external repository
          base-branch: "main"                  # Create PR against this branch
```

### Multiple Branch Syncs

```yml
name: Sync Multiple Branches

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
        
      - name: Sync fork main branch
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
        
      - name: Create PR from develop to main
        uses: melMass/actions@sync-fork
        with:
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          feature-branch: "develop"
          upstream-branch: "develop"
          base-branch: "main"  # Creates PR from develop to main
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
