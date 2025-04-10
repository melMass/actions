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

### Sync Fork (`@sync-fork`)

Automatically syncs a fork with its upstream repository and manages the pull request.

```yml
uses: melMass/actions@sync-fork
with:
  repo-token: ${{ secrets.GITHUB_TOKEN }}  # Required
  feature-branch: "main"  # Required: branch in the fork to update
  upstream-branch: "main"  # Required: upstream branch to sync from
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
