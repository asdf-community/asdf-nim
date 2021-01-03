![Build](https://github.com/asdf-community/asdf-nim/workflows/Build/badge.svg)

# asdf-nim

A [Nim](https://nim-lang.org) plugin for the [asdf](https://asdf-vm.com) version manager.

This plugin installs the `nim` compiler and tools (`nimble`, `nimgrep`, etc).

Pre-compiled [official binaries](#official-binaries) are installed if available for the current platform.

If no official binaries exist, [unoffical binaries](#unofficial-binaries) are installed.

If there are no binaries for the platform, Nim is built from source.

## Installation

If not already installed, [install asdf](https://asdf-vm.com/#/core-manage-asdf?id=install).

Then install `asdf-nim` and its dependencies with:

```sh
asdf plugin add nim https://github.com/asdf-community/asdf-nim
asdf nim install-deps
```

Updating the plugin later is easy:

```sh
asdf plugin update nim main
```

## Managing Nim Versions

The latest Nim can be installed with:

```sh
asdf install nim
```

Or for a specific version:

```sh
asdf install nim 1.4.2
```

Or even a specific git ref:

```sh
asdf install nim ref:17992fca1dc0b3674dce123296b277551bbca1db
```

To specify a version of Nim for a project:

```sh
asdf local nim <nim-version>
```

To have multiple of the same version of Nim installed, each with their own nimble packages, see [asdf-alias](https://github.com/andrewthauer/asdf-alias).

For additional plugin usage see the [asdf documentation](https://asdf-vm.com/#/core-manage-asdf).

## Nimble

Nimble packages are version-specific and installed in `~/.asdf/installs/nim/<nim-version>/nimble/pkgs`.

## Official binaries

[nim-lang.org](https://nim-lang.org/install.html) supplies binaries for:

Linux:

- `x86_64` (gnu libc)
- `x86` (gnu libc)

## Unofficial binaries

[nim-builds](https://github.com/elijahr/nim-builds) supplies binaries for other platforms, including macOS, non-x86 CPUs, and Linux distros that use the musl C standard library instead of GNU libc, such as Alpine Linux.

Linux:

- `x86_64` (musl)
- `armv5` (gnu libc)
- `armv6` (musl)
- `armv7` (gnu libc & musl)
- `aarch64`/`arm64`/`armv8` (gnu libc & musl)
- `powerpc64le` (gnu libc)

macOS:

- `x86_64`

## Contributing

Pull requests are welcome!

Dev dependencies for linting and unit tests are installed via:

```shell
npm install --include=dev
```

This project uses [bats](https://github.com/bats-core/bats-core) for unit testing. Tests are found in the `test` directory and can be run with:

```shell
npx bats test
```

This project uses various linters, they can be enabled to auto-format code via:

```
git config --local core.hooksPath .githooks
```

Note: `asdf plugin add nim .` will install the plugin from git HEAD. Any uncommitted changes won't be installed. I suggest instead installing via a symlink, so asdf uses your code exactly as it is during development: `ln -s "$(pwd)" ~/.asdf/plugins/nim`.

A few ideas for contributions:

- Shell completion
- Windows support (does asdf support Windows?)

## Changelog

### v1.0.0 - 2020-01-06

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
