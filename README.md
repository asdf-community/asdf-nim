![Build](https://github.com/asdf-community/asdf-nim/workflows/Build/badge.svg) ![Lint](https://github.com/asdf-community/asdf-nim/workflows/Lint/badge.svg) ![Latest Nim](https://github.com/asdf-community/asdf-nim/workflows/Latest%20Nim/badge.svg)

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

For additional plugin usage see the [asdf documentation](https://asdf-vm.com/#/core-manage-asdf).

## Nimble packages

Nimble packages are version-specific and installed in `~/.asdf/installs/nim/<nim-version>/nimble/pkgs`, unless a `nimbledeps` directory exists in your project. See the [nimble documentation](https://github.com/nim-lang/nimble#nimbles-folder-structure-and-packages) for more information about nimbledeps.

## Continuous Integration

### A simple example using GitHub Actions:

```yaml
name: Build
on:
  pull_request:
    paths-ignore:
      - README.md
  push:
    paths-ignore:
      - README.md
  schedule:
    - cron: '0 0 * * *' # daily at midnight

env:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

jobs:
  build:
    name: Test nim-${{ matrix.nim-version }} / ${{ matrix.runs-on }}
    strategy:
      fail-fast: false
      matrix:
        include:
          - runs-on: ubuntu-latest
            nim-version: latest
          - runs-on: macos-latest
            nim-version: latest

    runs-on: ${{ matrix.runs-on }}
    steps:
      - name: Checkout Nim project
        uses: actions/checkout@v2

      - name: Install asdf
        uses: asdf-vm/actions/setup@v1

      - name: Install asdf-nim
        run: |
          git clone \
            --branch main --depth 1
            https://github.com/asdf-community/asdf-nim.git \
            "${HOME}/asdf-nim
          asdf plugin add nim "${HOME}/asdf-nim"
          asdf nim install-deps -y

      - name: Install Nim
        run: |
          asdf install nim ${{ matrix.nim-version }}
          asdf local nim ${{ matrix.nim-version }}

      - name: Run tests
        run: |
          nimble develop -y
          nimble test
          nimble examples
```

### An example using GitHub Actions to test on non-x86 architectures:

```yaml
name: Build
on:
  pull_request:
    paths-ignore:
      - README.md
  push:
    paths-ignore:
      - README.md

jobs:
  test_non_x86:
    name: Test nim-${{ matrix.nim-version }} / debian-buster / ${{ matrix.arch }}
    strategy:
      fail-fast: false
      matrix:
        include:
          - nim-version: 1.4.2
            arch: armv7
          - nim-version: 1.2.8
            arch: aarch64
          - nim-version: 1.4.2
            arch: ppc64le

    runs-on: ubuntu-latest
    steps:
      - name: Checkout Nim project
        uses: actions/checkout@v2

      - uses: uraimo/run-on-arch-action@v2.0.8
        name: Install Nim & run tests
        with:
          arch: ${{ matrix.arch }}
          distro: buster

          dockerRunArgs: |
            --volume "${HOME}/.cache:/root/.cache"

          setup: mkdir -p "${HOME}/.cache"

          shell: /usr/bin/env bash

          install: |
            set -uexo pipefail
            # Install asdf and dependencies
            apt-get update -q -y
            apt-get -qq install -y build-essential curl git
            git clone https://github.com/asdf-vm/asdf.git "${HOME}/.asdf" --branch v0.8.0

          env: |
            GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

          run: |
            set -uexo pipefail
            . "${HOME}/.asdf/asdf.sh"

            # Install asdf-nim and dependencies
            git clone https://github.com/asdf-community/asdf-nim.git ~/asdf-nim --branch main --depth 1
            asdf plugin add nim ~/asdf-nim
            asdf nim install-deps -y

            # Install Nim
            asdf install nim ${{ matrix.nim-version }}
            asdf local nim ${{ matrix.nim-version }}

            # Run tests
            nimble develop -y
            nimble test
            nimble examples
```

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

Dev dependencies for unit tests are installed via:

```shell
npm install --include=dev
```

This project uses [bats](https://github.com/bats-core/bats-core) for unit testing. Tests are found in the `test` directory and can be run with:

```shell
npm run test
```

This project uses [lintball](https://github.com/elijahr/lintball) to auto-format code. Enable the githooks with:

```
git config --local core.hooksPath .githooks
```

Note: `asdf plugin add nim .` will install the plugin from git HEAD. Any uncommitted changes won't be installed. I suggest instead installing via a symlink, so asdf uses your code exactly as it is during development: `ln -s "$(pwd)" ~/.asdf/plugins/nim`.

A few ideas for contributions:

- Shell completion
- Windows support (does asdf support Windows?)
