# Actions

The `main` branch is used for testing the actions.  
Branches starting with `dev/` are either wip or experiments.

## Available Actions

### Build Python Wheels (`@build-python-wheels`)

Build wheels for pip libraries that require being built from source.

```yml
uses: melMass/actions@build-python-wheels
with:
  wheels: "numpy,scipy"  # Required: comma separated list of wheels to build
  python-version: "3.10"  # Optional: defaults to 3.10
  requirements-file: "requirements.txt"  # Optional
  dependencies: "wheel setuptools"  # Optional: additional dependencies to install
```

### Package Python Environment (`@package-python`)

Packages a Python environment with its dependencies for later use.

```yml
uses: melMass/actions@package-python
with:
  python-version: "3.10"  # Optional: defaults to 3.10
  requirements-file: "requirements.txt"  # Optional: defaults to requirements.txt
  dependencies: "numpy scipy"  # Optional: inline array of dependencies
  mode: "install"  # Optional: defaults to install
```

**Outputs:**
- `env-zip-path`: The full path of the zipped environment

### Workflow Summary (`@summary`)

Create beautiful workflow summaries with ease, supporting variable substitution, conditional sections, and pre-defined templates.

```yml
uses: melMass/actions@summary
with:
  content: |
    # 🚀 Deployment Summary
    
    ## 📦 Build Information
    
    | Property | Value |
    | --- | --- |
    | 🔄 Repository | ${repository} |
    | 🌿 Branch | ${branch} |
    
    ✅ Deployment completed successfully!
  variables: '{"repository": "${{ github.repository }}", "branch": "${{ github.ref_name }}"}'
```

### Nushell Kit (`@nukit`)

An opinionated action for running Nushell scripts with built-in toolkit functions.

```yml
uses: melMass/actions@nukit
with:
  script: |
    let data = {
      version: "1.0.0",
      status: "success"
    }
    $data | to-github --output  # Outputs to GITHUB_OUTPUT
  skip_modules: "false"  # Optional: defaults to false
  nu-version: "*"  # Optional: defaults to latest stable
```

### Sync Fork with Upstream (`@sync-fork`)

Automatically syncs a forked repository with its upstream repository and manages the pull request process.

**How it works:**
1. Syncs your fork with the upstream repository using GitHub's `mergeUpstream` API
2. If a PR already exists for the branch, adds a comment with update information
3. If no PR exists, creates a new PR to track the changes

**Perfect for:**
- Maintaining forks of actively developed repositories
- Keeping your fork in sync with the original repository
- Automating the tedious process of syncing forks

```yml
uses: melMass/actions@sync-fork
with:
  repo-token: ${{ secrets.GITHUB_TOKEN }}  # Required: GitHub token with repo access
  feature-branch: "main"  # Required: branch in your fork to update
  upstream-branch: "main"  # Required: upstream branch to sync from
```

**Example workflow (scheduled sync):**
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

### Deploy to IPFS (`@ipfs`) - Deprecated

~~Deploys a folder to IPFS and returns the CID.~~

```yml
uses: melMass/actions@ipfs
with:
  path: "build"  # Required: folder to upload, defaults to "build"
```

**Outputs:**
- `cid`: The CID of the uploaded artifact
