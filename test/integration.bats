#!/usr/bin/env bats

# shellcheck disable=SC2230

load ../node_modules/bats-support/load.bash
load ../node_modules/bats-assert/load.bash

setup_file() {
  export PROJECT_DIR
  PROJECT_DIR="$(realpath "$(dirname "$BATS_TEST_DIRNAME")")"
  cd "$PROJECT_DIR"

  export ASDF_NIM_TEST_TEMP
  ASDF_NIM_TEST_TEMP="$(mktemp -t asdf-nim-integration-tests.XXXX -d)"
  ASDF_DATA_DIR="${ASDF_NIM_TEST_TEMP}/asdf"
  export ASDF_DATA_DIR
  mkdir -p "$ASDF_DATA_DIR"
  git clone --branch=v0.8.0 --depth=1 https://github.com/asdf-vm/asdf.git "$ASDF_DATA_DIR"
  mkdir -p "$ASDF_DATA_DIR/plugins"

  # shellcheck disable=SC1090
  source "${ASDF_DATA_DIR}/asdf.sh"
}

teardown_file() {
  rm -rf "${ASDF_NIM_TEST_TEMP}"
}

teardown() {
  asdf plugin remove nim || true
}

info() {
  echo "# ${*} …" >&3
}

@test "nimble configuration" {
  # `asdf plugin add nim .` would only install from git HEAD.
  # So, we mock an installation via a symlink.
  # This makes it easier to run tests while developing.
  ln -s "$PROJECT_DIR" "${ASDF_DATA_DIR}/plugins/nim"

  info "asdf install nim 1.6.0"
  asdf install nim 1.6.0
  asdf local nim 1.6.0

  ASDF_INSTALL_PATH="${ASDF_DATA_DIR}/installs/nim/1.6.0"

  # Assert package index is placed in the correct location
  info "nimble refresh"
  nimble refresh -y
  assert [ -f "${ASDF_INSTALL_PATH}/nimble/packages_official.json" ]

  # Assert package installs to correct location
  info "nimble install -y nimjson@1.2.8"
  nimble install -y nimjson@1.2.8
  assert [ -x "${ASDF_INSTALL_PATH}/nimble/bin/nimjson" ]
  assert [ -f "${ASDF_INSTALL_PATH}/nimble/pkgs/nimjson-1.2.8/nimjson.nimble" ]

  # Assert that shim was created for package binary
  assert [ -n "$(command -v nimjson)" ]

  # Assert that nim finds nimble packages
  echo "import nimjson" >"${ASDF_NIM_TEST_TEMP}/testnimble.nim"
  info "nim c -r \"${ASDF_NIM_TEST_TEMP}/testnimble.nim\""
  nim c -r "${ASDF_NIM_TEST_TEMP}/testnimble.nim"
}

@test "nimble configuration with nimbledeps" {
  # `asdf plugin add nim .` would only install from git HEAD.
  # So, we mock an installation via a symlink.
  # This makes it easier to run tests while developing.
  ln -s "$PROJECT_DIR" "${ASDF_DATA_DIR}/plugins/nim"

  rm -rf nimbledeps
  mkdir "./nimbledeps"

  info "asdf install nim 1.6.0"
  asdf install nim 1.6.0
  asdf local nim 1.6.0

  ASDF_INSTALL_PATH="${ASDF_DATA_DIR}/installs/nim/1.6.0"

  # Assert package index is placed in the correct location
  info "nimble refresh"
  nimble refresh -y
  assert [ -f "./nimbledeps/packages_official.json" ]

  # Assert package installs to correct location
  info "nimble install -y nimjson@1.2.8"
  nimble install -y nimjson@1.2.8
  assert [ -x "./nimbledeps/bin/nimjson" ]
  assert [ -f "./nimbledeps/pkgs/nimjson-1.2.8/nimjson.nimble" ]

  # Assert that nim finds nimble packages
  echo "import nimjson" >"${ASDF_NIM_TEST_TEMP}/testnimble.nim"
  info "nim c --nimblePath:./nimbledeps/pkgs -r \"${ASDF_NIM_TEST_TEMP}/testnimble.nim\""
  nim c --nimblePath:./nimbledeps/pkgs -r "${ASDF_NIM_TEST_TEMP}/testnimble.nim"

  rm -rf nimbledeps
}
