
# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

### v1.1.3 - 2021-03-04

- Allow nimble shim ti work in elvish shell.

### v1.1.2 - 2021-01-30

- Add support for Apple Silicon / M1

### v1.1.2 - 2021-01-30

- Add support for Apple Silicon / M1

### v1.1.1 - 2021-01-24

- Update to lintball 1.1.3

### v1.1.0 - 2021-01-18

- Support for bash 3
- Remove hard dependency on gcc for determining ARM version
- Fix build issues on GitHub Actions
- Reformat code with [lintball](https://github.com/elijahr/lintball)

### v1.0.0 - 2021-01-06

- Refactor
- Fix issues with nimble shim
- Add unit & integration tests

### v0.2.1 - 2021-01-02

- Bugfix: issue with tarball name generation causing unnecessary building from source.

### v0.2.0 - 2021-01-02

- Bugfix: armv7 could not curl even with update-ca-certificates. Bundle latests cacert.pem.
- Bugfix: perms issue where asdf cleanup handler would block on rm of fusion/.git/\* files
- Workaround for CI: disable TCP offloading so can run tests again macOS again
- Add pre-commit git hooks for shfmt and prettier
- Test on CI: Alpine / musl

### v0.1.0 - 2021-01-01

- Initial release
