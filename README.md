# @melmass/build-python-wheels

Build wheels for pip libraries that require being built from source.

## Inputs

- `wheels`: comma separated list of wheels to build
- `python-version`: the version of python to target
- `requirements-file`: the path to the requirements.txt file
- `dependencies`: inline array of dependencies to install

Only `wheels` is required, all other inputs are optional.  
If not provided these are the defaults:

```yaml
- with:
    python-version: "3.10"
```
