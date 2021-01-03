![Build](https://github.com/asdf-community/asdf-nim/workflows/Build/badge.svg)

# asdf-nim

A [Nim](https://nim-lang.org) plugin for the [asdf](https://asdf-vm.com) version manager.

This plugin installs the `nim` compiler and tools (`nimble`, `nimgrep`, etc).

Pre-compiled [official binaries](#official-binaries) are installed if available for the current platform.

If no official binaries exist, [unoffical binaries](#unofficial-binaries) are installed.

If there are no binaries for the platform, Nim is built from source.

CI tests the plugin with Nim versions 0.20.x, 1.0.x, 1.2.x, and 1.4.x.

Nimble packages are installed in `~/.asdf/installs/nim/<nim-version>/nimble/pkgs`.

## Installation

If not already installed, [install asdf](https://asdf-vm.com/#/core-manage-asdf?id=install).

Then install `asdf-nim` and its dependencies with:

```sh
asdf plugin add nim https://github.com/asdf-community/asdf-nim
asdf nim install-deps
```

For the latest fixes and improvements to the plugin, updating is easy:

```sh
asdf plugin update nim devel
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

A `.tool-versions` file can be used to specify various project requirements in one place, such as:

```
nim 1.4.2
python 3.9.1
ruby 3.0.0
nodejs 15.5.0
```

The versions in `.tool-versions` will be installed simply by running `asdf install`. You can create a `.tool-versions` for your project with `asdf local nim <nim-version>`.

For additional plugin usage see the [asdf documentation](https://asdf-vm.com/#/core-manage-asdf).

## Official binaries

[nim-lang.org](https://nim-lang.org/install.html) supplies binaries for:

Linux:

- `x86_64` (glibc)
- `x86` (glibc)

## Unofficial binaries

[nim-builds](https://github.com/elijahr/nim-builds) supplies binaries for:

Linux:

- `x86_64` (musl)
- `armv5` (glibc)
- `armv6` (musl)
- `armv7` (glibc & musl)
- `aarch64`/`arm64`/`armv8` (glibc & musl)
- `powerpc64le` (glibc)

macOS:

- `x86_64`

## Contributing

Pull requests are welcome!

One idea: unit tests with [Bats](https://github.com/sstephenson/bats).

This project uses various linters, they can be enabled to auto-fix any commits via:

```
npm install --include=dev
git config --local core.hooksPath .githooks
```

## Changelog

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
