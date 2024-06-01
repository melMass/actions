# @melmass/nukit

This is an opiniated action around nushell, relying on the great [setup-nu](https://github.com/hustcer/setup-nu).

The main goal was to have the fastest way to write inline nushell.

By default it ships with a [toolkit](./toolkit.nu) overlay that is in scope and usable directly. You can skip it by setting the `skip_modules` input to `true`.

You can then write inline nushell, a few features:
- **supports loading overlays**, these should be relative to the execution location (usually the workspace root)
- Some predefined methods useful in the action context (more to come):
    - `to-github`: pipe a record to GITHUB_ENV (by default) or GITHUB_OUTPUT (using the `--output(-o)` flag)

For an example usage check the [test](./.github/workflows/test.yml) file

## Inputs

- `repo-token`: "not used"
- `script`: The inline nushell code to execute
- `script-file`: Use a nushell script from the checked out repo.
- `skip_modules`: Skip the "kit" modules
- `nu-version`: The version of nushell to install, defaults to `*`, i.e latest stable.

All the inputs are optional but you still need either a script or a scrip-file. This is the default values used when none are given:

```yaml
- with:
   skip_modules: "false"
   nu-version: "*"
```

## Outputs

None


