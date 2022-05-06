![Build](https://github.com/asdf-community/asdf-nim/workflows/Build/badge.svg) ![Lint](https://github.com/asdf-community/asdf-nim/workflows/Lint/badge.svg) ![Latest Nim](https://github.com/asdf-community/asdf-nim/workflows/Latest%20Nim/badge.svg)

# asdf-nim

asdf-nim allows you to quickly install any version of [Nim](https://nim-lang.org).

asdf-nim is intended for end-users and continuous integration. Whether macOS or Linux, x86 or ARM - all you need to install Nim in a few seconds is bash.

## Installation

[Install asdf](https://asdf-vm.com/guide/getting-started.html), then:

```sh
asdf plugin add nim
asdf nim install-deps
asdf install nim 1.6.6 # or another version of Nim such as 1.4.8 or ref:HEAD
```

To use a specific version of Nim only within a directory:

```sh
asdf local nim 1.6.6
```

For additional plugin usage see the [asdf documentation](https://asdf-vm.com/#/core-manage-asdf).

## Nimble packages

Nimble packages are installed in `~/.asdf/installs/nim/<nim-version>/nimble/pkgs`, unless a `nimbledeps` directory exists in the directory where `nimble install` is run from.

See the [nimble documentation](https://github.com/nim-lang/nimble#nimbles-folder-structure-and-packages) for more information about nimbledeps.

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
    name: Test
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: Install Nim
        uses: asdf-vm/actions/install@v1
        with:
          tool_versions: |
            nim 1.6.6
      - name: Run tests
        run: |
          asdf local nim 1.6.6
          nimble develop -y
          nimble test
          nimble examples
```

### Continuous Integration on Non-x86 Architectures

This uses [uraimo/run-on-arch-action](https://github.com/uraimo/run-on-arch-action):

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
          - nim-version: 1.6.6
            arch: armv7
          - nim-version: 1.2.18
            arch: aarch64
          - nim-version: 1.4.8
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

## Official Nim binaries

[nim-lang.org](https://nim-lang.org/install.html) supplies binaries of Nim for:

Linux:

- `x86_64` (gnu libc)
- `x86` (gnu libc)

## Unofficial Nim binaries

[nim-builds](https://github.com/elijahr/nim-builds) supplies binaries of Nim for other platforms, including macOS, non-x86 CPUs, and Linux distros that use the musl C standard library instead of GNU libc, such as Alpine Linux.

Linux:

- `x86_64` (musl)
- `armv5` (gnu libc)
- `armv6` (musl)
- `armv7` (gnu libc & musl)
- `aarch64`/`arm64`/`armv8` (gnu libc & musl)
- `powerpc64le` (gnu libc)

macOS:

- `x86_64`

## Updating the plugin

```sh
asdf plugin update nim main
```

## Contributing

Pull requests are welcome!

Fork this repo, then run:

```
# warning: this will clear any existing nim installations made via asdf-nim
rm -rf ~/.asdf/plugins/nim
git clone git@github.com:<your-username>/asdf-nim.git ~/.asdf/plugins/nim
```

Dev dependencies for unit tests are installed via:

```shell
cd ~/.asdf/plugins/nim
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

A few ideas for contributions:

- Shell completion
- Windows support (does asdf support Windows?)
