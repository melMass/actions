# @melmass/package-python

This action packages a python environment with it dependencies.
For an example usage check the [test](./.github/workflows/test.yml) file

## Inputs

- `python-version`: the version of python to install
- `requirements-file`: the path to the requirements.txt file
- `dependencies`: inline array of dependencies
- `mode`: the mode of the action.

All the inputs are optional. This is the default values used when none are given:

```yaml
- with:
   python-version: "3.10"
   requirements-file: "requirements.txt"
   mode: "install"
```

## Outputs

- `env-zip-path`: the full path of the zipped environment


