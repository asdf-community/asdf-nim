# Contributing

Testing Locally:

```shell
asdf plugin test <plugin-name> <plugin-url> [--asdf-tool-version <version>] [--asdf-plugin-gitref <git-ref>] [test-command*]

#
asdf plugin test nim https://github.com/asdf-community/asdf-nim.git "nim -v"
```

Tests are automatically run in GitHub Actions on push and PR.
