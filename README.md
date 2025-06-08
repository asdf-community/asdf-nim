[![build](https://github.com/asdf-community/asdf-nim/actions/workflows/build.yml/badge.svg)](https://github.com/asdf-community/asdf-nim/actions/workflows/build.yml) [![lint](https://github.com/asdf-community/asdf-nim/actions/workflows/lint.yml/badge.svg)](https://github.com/asdf-community/asdf-nim/actions/workflows/lint.yml)

# asdf-nim

asdf-nim allows you to quickly install any version of [Nim](https://nim-lang.org).

asdf-nim works for both personal development and continuous integration. It runs on macOS and Linux, supporting x86, ARM, and other architectures.

## Installation

[Install asdf](https://asdf-vm.com/guide/getting-started.html), then:

```sh
asdf plugin add nim # install the asdf-nim plugin
asdf nim install-deps  # install system-specific dependencies for downloading & building Nim
```

### To install Nim:

When available for the version and platform, the plugin will install pre-compiled binaries of Nim. If no binaries are available the plugin will build Nim from source.

```sh
# latest stable version of Nim
asdf install nim latest
# or latest stable minor/patch release of Nim 2.x.x
asdf install nim latest:2
# or latest stable patch release of Nim 2.2.x
asdf install nim latest:2.2
# or specific patch release
asdf install nim 2.2.0
```

### To install a nightly build of Nim:

```sh
# nightly unstable build of devel branch
asdf install nim ref:devel
# or nightly unstable build of version-2-2 branch, i.e. the 2.2.x release + any recent backports from devel
asdf install nim ref:version-2-2
# or nightly unstable build of version-1-6 branch, i.e. the latest 1.6.x release + any recent backports from devel
asdf install nim ref:version-1-6
```

### To build a specific git commit or branch of Nim:

```sh
# build using latest commit from the devel branch
asdf install nim ref:HEAD
# build using the specific commit 7d15fdd
asdf install nim ref:7d15fdd
# build using the tagged release v2.2.0
asdf install nim ref:v2.2.0
```

### To set the default version of Nim for your user:

```sh
asdf global nim latest:2.2
```

This creates a `.tool-versions` file in your home directory specifying the Nim version.

### To set the version of Nim for a project directory:

```sh
cd my-project
asdf local nim latest:2.2
```

This creates a `.tool-versions` file in the current directory specifying the Nim version. For additional plugin usage see the [asdf documentation](https://asdf-vm.com/#/core-manage-asdf).

## Nimble packages

Nimble packages are installed in `~/.asdf/installs/nim/<nim-version>/nimble/pkgs`, unless a `nimbledeps` directory exists in the directory where `nimble install` is run from.

See the [nimble documentation](https://github.com/nim-lang/nimble#nimbles-folder-structure-and-packages) for more information about nimbledeps.

## Continuous Integration

### A simple example using GitHub Actions:

```yaml
name: Build
on:
  push:
    paths-ignore:
      - README.md

env:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

jobs:
  build:
    name: Test
    runs-on: ${{ matrix.os }}
    matrix:
      include:
        # Test against stable Nim builds on linux
        - os: ubuntu-latest
          nim-version: latest:2.2
        - os: ubuntu-latest
          nim-version: latest:1.6

        # Test against unstable nightly Nim builds on macos x64 (faster than building from source)
        - os: macos-latest
          nim-version: ref:version-2-2
        - os: macos-latest
          nim-version: ref:version-1-6
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Install Nim
        uses: asdf-vm/actions/install@v1
        with:
          tool_versions: |
            nim ${{ matrix.nim-version }}
      - name: Run tests
        run: |
          asdf local nim ${{ matrix.nim-version }}
          nimble develop -y
          nimble test
          nimble examples
```

### Continuous Integration on Non-x86 Architectures

Using [uraimo/run-on-arch-action](https://github.com/uraimo/run-on-arch-action):

```yaml
name: Build
on:
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
          - nim-version: ref:version-2-2
            arch: armv7
          - nim-version: ref:version-1-6
            arch: aarch64

    runs-on: ubuntu-latest
    steps:
      - name: Checkout Nim project
        uses: actions/checkout@v4

      - uses: uraimo/run-on-arch-action@v2
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
            git clone https://github.com/asdf-vm/asdf.git "${HOME}/.asdf" --branch v0.14.1

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

## Stable binaries

[nim-lang.org](https://nim-lang.org/install.html) supplies pre-compiled stable binaries of Nim for:

Linux:

- `x86_64` (gnu libc)
- `x86` (gnu libc)

## Unstable nightly binaries

[nim-lang/nightlies](https://github.com/nim-lang/nightlies) supplies pre-compiled unstable binaries of Nim for:

Linux:

- `x86_64` (gnu libc)
- `x86` (gnu libc)
- `aaarch64` (gnu libc)
- `armv7l` (gnu libc)

macOS:

- `x86_64`

## Updating asdf and asdf-nim

```sh
asdf update
asdf plugin update nim main
```

## Contributing

Pull requests are welcome!

Fork this repo, then run:

```sh
rm -rf ~/.asdf/plugins/nim
git clone git@github.com:<your-username>/asdf-nim.git ~/.asdf/plugins/nim
```

### Testing

This project uses [bats](https://github.com/bats-core/bats-core) for unit testing. Please follow existing patterns and add unit tests for your changeset. Dev dependencies for unit tests are installed via:

```shell
cd ~/.asdf/plugins/nim
npm install --include=dev
```

Run tests with:

```sh
npm run test
```

### Linting

This project uses [lintball](https://github.com/elijahr/lintball) to auto-format code. Please ensure your changeset passes linting. Enable the githooks with:

```sh
git config --local core.hooksPath .githooks
```
