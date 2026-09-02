# Contributing

When opening a pull request:

- Do not change the version in `info.json`. Version bumping is handled by the release workflow.
- Document any user-visible change in the `Unreleased` section of `changelog.txt`.

## Changelog

The `Unreleased` section is removed on release, so between releases `changelog.txt`
starts with the last released version. If there is no `Unreleased` section, prepend
this block:

```
---------------------------------------------------------------------------------------------------
Version: Unreleased
```
