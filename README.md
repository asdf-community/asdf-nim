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

Pre-built nightly binaries are available for some platforms and branches:

```sh
# nightly unstable build of devel branch (pre-built binaries available for most platforms)
asdf install nim ref:devel
# or nightly unstable build of version-2-2 branch (pre-built binaries available for most platforms)
asdf install nim ref:version-2-2
# or nightly unstable build of version-2-0 branch (pre-built binaries available for most platforms)
asdf install nim ref:version-2-0
```

For older versions, the plugin will build from source (no pre-built nightly binaries):

```sh
# build from version-1-6 branch source (no pre-built nightlies available)
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
asdf set --home nim latest:2.2
```

This creates a `.tool-versions` file in your home directory specifying the Nim version.

### To set the version of Nim for a project directory:

```sh
cd my-project
asdf set nim latest:2.2
```

This creates a `.tool-versions` file in the current directory specifying the Nim version. For additional plugin usage see the [asdf documentation](https://asdf-vm.com/#/core-manage-asdf).

## Nimble packages

In addition to global nimble package installation, asdf-nim works as expected with a[`nimbledeps`](https://github.com/nim-lang/nimble/issues/131#issuecomment-676624533) directory and the [atlas](https://github.com/nim-lang/atlas) package cloner.

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
        uses: asdf-vm/actions/install@v4
        with:
          tool_versions: |
            nim ${{ matrix.nim-version }}
      - name: Run tests
        run: |
          asdf set nim ${{ matrix.nim-version }}
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

      - uses: uraimo/run-on-arch-action@v3
        name: Install Nim & run tests
        with:
          arch: ${{ matrix.arch }}
          distro: bookworm

          dockerRunArgs: |
            --volume "${HOME}/.cache:/root/.cache"
            --volume "${GITHUB_WORKSPACE}:/workspace"

          setup: mkdir -p "${HOME}/.cache"

          shell: /usr/bin/env bash

          install: |
            set -uexo pipefail

            # Add Debian backports repository for newer Golang versions
            cat >/etc/apt/sources.list.d/debian-backports.sources <<EOF
            Types: deb deb-src
            URIs: http://deb.debian.org/debian
            Suites: bookworm-backports
            Components: main
            Enabled: yes
            Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
            EOF

            # Install dependencies
            apt-get update -q -y
            apt-fast install -qq -y curl git xz-utils build-essential
            apt-fast install -qq -y -t bookworm-backports golang-go
            go install github.com/asdf-vm/asdf/cmd/asdf@master

            # Install asdf-nim
            export PATH="/root/go/bin:${PATH}"
            asdf plugin add nim
            asdf nim install-deps -y

          env: |
            GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

          run: |
            set -uexo pipefail

            cd /workspace

            # Install Nim
            asdf install nim ${{ matrix.nim-version }}
            asdf set nim ${{ matrix.nim-version }}

            # Run tests
            nimble develop -y
            nimble test
            nimble examples
```

## Stable binaries

[nim-lang.org](https://nim-lang.org/install.html) supplies pre-compiled stable binaries of Nim for:

Linux:

- `x86_64`
- `x86`

## Exact version matching via nightly builds

For platforms without official stable binaries (ARM Linux, macOS ARM64, etc.), the plugin automatically finds and uses exact nightly builds matching the requested stable version.

When you install a specific version like `2.2.4` on a platform without official binaries:

```sh
asdf install nim 2.2.4
```

The plugin will:

1. Check for official stable binaries (x86_64/x86 Linux only)
2. If none available, search for exact nightly builds matching the version's commit hash
3. Use the matching nightly build (typically built within 1-2 days of the release)
4. Fall back to building from source if no exact nightly found

This means **ARM users get exact stable versions in seconds instead of minutes** building from source.

### Benefits

- **ARM Linux** (aarch64, armv7l): Get exact stable versions without building from source
- **macOS ARM64**: Get older stable versions that predate official ARM64 support
- **Faster CI/CD**: Consistent, fast installations across all platforms
- **Exact versions**: Same version across x86 and ARM platforms

### Opt-out

To always build from source instead of using exact nightly matches:

```sh
export ASDF_NIM_NO_NIGHTLY_FALLBACK=1
asdf install nim 2.2.4
```

## Unstable nightly binaries

[nim-lang/nightlies](https://github.com/nim-lang/nightlies) supplies pre-compiled unstable binaries of Nim. This plugin automatically detects available nightly releases via the GitHub API.

When installing a nightly version (e.g., `ref:devel` or `ref:version-2-2`), the plugin will:

1. Query the GitHub releases API to find available nightly builds (checks up to 4 pages of releases)
2. Select the most recent nightly that matches your platform and desired version
3. Fall back to building from source if no matching prebuilt nightly is found

Common platforms with nightly support:

Linux:

- `x86_64`
- `x86`
- `aarch64`
- `armv7l`

macOS:

- `x86_64`
- `arm64`

**Note**: All Nim binaries (stable and nightly) are portable and work on both glibc-based (Ubuntu, Debian, etc.) and musl-based (Alpine Linux, etc.) systems.

**Note**: To avoid GitHub API rate limits (60 requests/hour without authentication), set the `GITHUB_TOKEN` environment variable with a personal access token. The plugin will automatically use it for API requests.

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

#### Test Performance Optimization

For faster local development, you can skip slow integration tests:

```sh
# Run only fast unit tests (~60s)
ASDF_NIM_SKIP_INTEGRATION=1 npm run test

# Run all tests including integration tests (~5-10 min)
npm run test
```

**Test Types:**

- **Unit tests** (`test/utils.bats`): Fast, mocked, test individual functions
- **Integration tests** (`test/integration.bats`): Slow, install real Nim versions

**CI Caching:** Integration tests cache Nim installations between runs for speed.

### Linting

This project uses [pre-commit](https://pre-commit.com/) to auto-format code. Please ensure your changeset passes linting. Install and enable pre-commit with:

```sh
pip install pre-commit
pre-commit install
```
