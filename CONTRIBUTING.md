# Contributing

When opening a pull request:

- Do not change the version in `info.json`. Version bumping is handled by the release workflow.
- Document any user-visible change in the `Unreleased` section of `changelog.txt`.

## Changelog

On release the `Unreleased` section is replaced by the released version, so
between releases `changelog.txt` starts with the last released version. If there
is no `Unreleased` section, prepend this block:

```
---------------------------------------------------------------------------------------------------
Version: Unreleased
```
