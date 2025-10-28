#!/usr/bin/env bats

# shellcheck disable=SC2230

load ../node_modules/bats-support/load.bash
load ../node_modules/bats-assert/load.bash
load ./lib/test_utils

setup_file() {
  # Allow skipping slow integration tests for fast local development
  if [ "${ASDF_NIM_SKIP_INTEGRATION:-0}" = "1" ]; then
    skip "Integration tests skipped (set ASDF_NIM_SKIP_INTEGRATION=0 to run)"
  fi

  # shellcheck disable=SC2154
  PROJECT_DIR="$(realpath "$(dirname "$BATS_TEST_DIRNAME")")"
  export PROJECT_DIR
  cd "$PROJECT_DIR" || exit

  # Use cached asdf installation for speed
  ASDF_VERSION="v0.18.0"
  ASDF_CACHE_DIR="${PROJECT_DIR}/.test-cache/asdf-${ASDF_VERSION}"
  if [ -d "${ASDF_CACHE_DIR}" ]; then
    # Use cached asdf - no git lock needed!
    ASDF_DIR="$(mktemp -t asdf-nim-integration-tests.XXXX -d)"
    cp -R "${ASDF_CACHE_DIR}/." "$ASDF_DIR/"
    export ASDF_DIR
  else
    # First run: clone, build, and cache
    ASDF_DIR="$(mktemp -t asdf-nim-integration-tests.XXXX -d)"
    export ASDF_DIR

    get_lock git
    git clone \
      --branch="${ASDF_VERSION}" \
      --depth=1 \
      https://github.com/asdf-vm/asdf.git \
      "$ASDF_DIR"
    clear_lock git

    # Build asdf (v0.18.0+ requires Go build)
    (cd "$ASDF_DIR" && make build)

    # Copy the compiled Go binary over the old Bash script in bin/
    cp "$ASDF_DIR/asdf" "$ASDF_DIR/bin/asdf"

    # Cache for future test runs
    mkdir -p "$(dirname "$ASDF_CACHE_DIR")"
    cp -R "$ASDF_DIR" "$ASDF_CACHE_DIR"
  fi
}

teardown_file() {
  clear_lock git
  rm -rf "$ASDF_DIR"
}

setup() {
  ASDF_NIM_TEST_TEMP="$(mktemp -t asdf-nim-integration-tests.XXXX -d)"
  export ASDF_NIM_TEST_TEMP
  ASDF_DATA_DIR="${ASDF_NIM_TEST_TEMP}/asdf"
  export ASDF_DATA_DIR
  mkdir -p "$ASDF_DATA_DIR/plugins"

  # `asdf plugin add nim .` would only install from git HEAD.
  # So, we install by copying the plugin to the plugins directory.
  cp -R "$PROJECT_DIR" "${ASDF_DATA_DIR}/plugins/nim"
  cd "${ASDF_DATA_DIR}/plugins/nim" || exit

  # For asdf 0.16.0+, source the asdf.sh wrapper which sets up PATH
  # shellcheck disable=SC1090,SC1091
  source "${ASDF_DIR}/asdf.sh"

  ASDF_NIM_VERSION_INSTALL_PATH="${ASDF_DATA_DIR}/installs/nim/ref-version-2-2"
  export ASDF_NIM_VERSION_INSTALL_PATH

  # Use a shared cache directory for faster test runs
  # This avoids depending on the user's real installation
  ASDF_NIM_CACHE_DIR="${PROJECT_DIR}/.test-cache"
  mkdir -p "${ASDF_NIM_CACHE_DIR}"

  info "asdf install nim ref:version-2-2"
  if [ -d "${ASDF_NIM_CACHE_DIR}/nim-ref-version-2-2" ]; then
    # Use cached installation for speed
    mkdir -p "${ASDF_DATA_DIR}/installs/nim"
    cp -R "${ASDF_NIM_CACHE_DIR}/nim-ref-version-2-2" "${ASDF_NIM_VERSION_INSTALL_PATH}"
    rm -rf "${ASDF_NIM_VERSION_INSTALL_PATH}/nimble"
    asdf reshim
  else
    # First run: install and cache
    get_lock git
    asdf install nim ref:version-2-2
    clear_lock git
    # Cache for future test runs (gitignored)
    mkdir -p "${ASDF_NIM_CACHE_DIR}"
    cp -R "${ASDF_NIM_VERSION_INSTALL_PATH}" "${ASDF_NIM_CACHE_DIR}/nim-ref-version-2-2"
  fi
  asdf set nim ref:version-2-2
}

teardown() {
  # Ensure we're operating on the test directory, not the real installation
  if [ -n "${ASDF_DATA_DIR}" ] && [[ "${ASDF_DATA_DIR}" == *"asdf-nim-integration-tests"* ]]; then
    asdf plugin remove nim || true
  else
    echo "WARNING: Skipping plugin removal - ASDF_DATA_DIR not set to test directory" >&2
  fi
  rm -rf "${ASDF_NIM_TEST_TEMP}"
}

info() {
  echo "# ${*} …" >&3
}

@test "nimble_configuration__without_nimbledeps" {
  # Assert package index is placed in the correct location
  info "nimble refresh -y"
  get_lock git
  nimble refresh -y
  clear_lock git
  assert [ -f "${ASDF_NIM_VERSION_INSTALL_PATH}/nimble/packages_official.json" ]

  # Assert package installs to correct location
  info "nimble install -y nimjson@1.2.8"
  get_lock git
  nimble install -y nimjson@1.2.8
  clear_lock git
  assert [ -x "${ASDF_NIM_VERSION_INSTALL_PATH}/nimble/bin/nimjson" ]
  # Nimble uses pkgs2/ directory structure with git hash suffix in newer versions
  nimble_file=$(find "${ASDF_NIM_VERSION_INSTALL_PATH}/nimble/pkgs2" -name "nimjson.nimble" -path "*/nimjson-1.2.8*/nimjson.nimble" | head -1)
  assert [ -n "$nimble_file" ]
  assert [ -f "$nimble_file" ]
  assert [ ! -x "./nimbledeps/bin/nimjson" ]

  # Assert that shim was created for package binary
  assert [ -f "${ASDF_DATA_DIR}/shims/nimjson" ]

  # Assert that correct nimjson is used
  assert [ -n "$(nimjson -v | grep ' version 1\.2\.8' || true)" ]

  # Assert that nim finds nimble packages
  echo "import nimjson" >"${ASDF_NIM_TEST_TEMP}/testnimble.nim"
  info "nim c -r \"${ASDF_NIM_TEST_TEMP}/testnimble.nim\""
  nim c -r "${ASDF_NIM_TEST_TEMP}/testnimble.nim"
}

@test "nimble_configuration__with_nimbledeps" {
  rm -rf nimbledeps
  mkdir "./nimbledeps"

  # Assert package index is placed in the correct location
  info "nimble refresh"
  get_lock git
  nimble refresh -y
  clear_lock git
  assert [ -f "./nimbledeps/packages_official.json" ]

  # Assert package installs to correct location
  info "nimble install -y nimjson@1.2.8"
  get_lock git
  nimble install -y nimjson@1.2.8
  clear_lock git
  assert [ -x "./nimbledeps/bin/nimjson" ]
  # Nimble uses pkgs2/ directory structure with git hash suffix in newer versions
  nimble_file=$(find "./nimbledeps/pkgs2" -name "nimjson.nimble" -path "*/nimjson-1.2.8*/nimjson.nimble" | head -1)
  assert [ -n "$nimble_file" ]
  assert [ -f "$nimble_file" ]
  assert [ ! -x "${ASDF_NIM_VERSION_INSTALL_PATH}/nimble/bin/nimjson" ]

  # Assert that nim finds nimble packages
  echo "import nimjson" >"${ASDF_NIM_TEST_TEMP}/testnimble.nim"
  info "nim c --nimblePath:./nimbledeps/pkgs2 -r \"${ASDF_NIM_TEST_TEMP}/testnimble.nim\""
  nim c --nimblePath:./nimbledeps/pkgs2 -r "${ASDF_NIM_TEST_TEMP}/testnimble.nim"

  rm -rf nimbledeps
}

@test "nimble_package_binary_in_path" {
  # Install nph package via nimble
  info "nimble install -y nph"
  get_lock git
  nimble install -y nph
  clear_lock git

  # Assert binary was installed to correct location
  assert [ -x "${ASDF_NIM_VERSION_INSTALL_PATH}/nimble/bin/nph" ]

  # Assert shim was created
  assert [ -f "${ASDF_DATA_DIR}/shims/nph" ]

  # Assert nph shim is in PATH and is the test's asdf shim (not system install)
  # The test's ASDF_DATA_DIR/shims should be first in PATH
  info "which nph"
  nph_path="$(which nph)"
  assert [ -n "$nph_path" ]
  assert [ "$nph_path" = "${ASDF_DATA_DIR}/shims/nph" ]

  # Assert nph runs successfully via the test's shim
  info "nph --version"
  run nph --version
  assert_success
  assert_output --regexp "^v[0-9]+"
}

@test "latest_installs_binary_when_available" {
  # Install a specific version using latest: syntax
  info "asdf install nim latest:2.0"
  get_lock git
  run asdf install nim latest:2.0
  clear_lock git
  assert_success

  # Verify it downloaded a pre-built binary (not built from source)
  # Look for download indicators in output
  assert_output --partial "Download"
  assert_output --partial "already built"

  # Verify it did NOT compile from source
  refute_output --partial "build_all.sh"
  refute_output --partial "make -C csources"

  # Verify nim was installed and works
  info "asdf list nim"
  run asdf list nim
  assert_success
  assert_output --partial "2.0"

  # Set and verify the version works
  asdf set nim latest:2.0
  info "nim --version"
  run nim --version
  assert_success
  assert_output --regexp "Nim Compiler Version 2\.0\.[0-9]+"
}
