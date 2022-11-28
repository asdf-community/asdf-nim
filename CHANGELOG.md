# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v2.0.1 - 2022-11-28

- fix: sorting for `asdf list-all nim`

## v2.0.0 - 2022-11-08

- add: nightly unstable binary support (ire4ever1190)
- add: docker-compose config for Linux development
- improve: linting (yaml, markdown, update shellcheck/shfmt)
- remove: unofficial binaries from nim-builds
- remove: hub dependency
- remove: untested windows support (does asdf even support mingw bash?)
- fix: fixed ASDF_INSTALL_PATH empty when version is ref:HEAD (joxcat)

## v1.4.0 - 2022-05-10

- add: binaries for Nim 1.2.18, 1.6.4, 1.6.6

### v1.3.2 - 2021-12-27

- fix: #14 ASDF_DATA_DIR default not sensible

### v1.3.1 - 2021-12-24

- add: binaries for Nim 1.2.16 and 1.6.2

### v1.3.0 - 2021-11-30

- fix: don't override XDG_CONFIG_HOME and APPDATA

### v1.2.3 - 2021-11-22

- fix: workaround for M1 `DYLD_LIBRARY_PATH`

### v1.2.1 - 2021-10-12

- fix: `asdf_nim_is_musl ` check

### v1.2.0 - 2021-10-09

- fix: missing `tools` directory
- deprecate: remove `ASDF_NIM_REQUIRE_BINARY` option

### v1.1.6 - 2021-10-08

- fix: CI: plugin test on Alpine Linux failed due to busybox grep missing -quiet
- fix: ASDF_INSTALL_PATH should not be assumed as set due to `list-all`

- ### v1.1.5 - 2021-7-11

- fix: Support for nimbledeps directory (#7)

### v1.1.4 - 2021-03-27

- fix: bats issues

### v1.1.3 - 2021-03-04

- feat: allow nimble shim to work in elvish shell

### v1.1.2 - 2021-01-30

- feat: support for Apple Silicon / M1

### v1.1.1 - 2021-01-24

- update: lintball 1.1.3

### v1.1.0 - 2021-01-18

- feat: support for bash 3
- fix: remove hard dependency on gcc for determining ARM version
- fix: build issues on GitHub Actions
- feat: reformat code with [lintball](https://github.com/elijahr/lintball)

### v1.0.0 - 2021-01-06

- feat: refactor
- fix: issues with nimble shim
- feat: add unit & integration tests

### v0.2.1 - 2021-01-02

- fix: issue with tarball name generation causing unnecessary building from source.

### v0.2.0 - 2021-01-02

- fix: armv7 could not curl even with update-ca-certificates. Bundle latest cacert.pem.
- fix: perms issue where asdf cleanup handler would block on rm of fusion/.git/\* files
- workaround: CI: disable TCP offloading so can run macOS tests again
- feat: add pre-commit git hooks for shfmt and prettier
- feat: test on CI: Alpine / musl

### v0.1.0 - 2021-01-01

- feat: initial release
