#!/usr/bin/env bats

# shellcheck disable=SC2230

load ../node_modules/bats-support/load.bash
load ../node_modules/bats-assert/load.bash
load ./lib/test_utils

setup_file() {
  PROJECT_DIR="$(realpath "$(dirname "$BATS_TEST_DIRNAME")")"
  export PROJECT_DIR
  cd "$PROJECT_DIR"
  clear_lock git

  ASDF_DIR="$(mktemp -t asdf-nim-integration-tests.XXXX -d)"
  export ASDF_DIR

  get_lock git
  git clone \
    --branch=v0.10.2 \
    --depth=1 \
    https://github.com/asdf-vm/asdf.git \
    "$ASDF_DIR"
  clear_lock git
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
  cd "${ASDF_DATA_DIR}/plugins/nim"

  # shellcheck disable=SC1090,SC1091
  source "${ASDF_DIR}/asdf.sh"

  ASDF_NIM_VERSION_INSTALL_PATH="${ASDF_DATA_DIR}/installs/nim/ref-version-1-6"
  export ASDF_NIM_VERSION_INSTALL_PATH

  # optimization if already installed
  info "asdf install nim ref:version-1-6"
  if [ -d "${HOME}/.asdf/installs/nim/ref-version-1-6" ]; then
    mkdir -p "${ASDF_DATA_DIR}/installs/nim"
    cp -R "${HOME}/.asdf/installs/nim/ref-version-1-6" "${ASDF_NIM_VERSION_INSTALL_PATH}"
    rm -rf "${ASDF_NIM_VERSION_INSTALL_PATH}/nimble"
    asdf reshim
  else
    get_lock git
    asdf install nim ref:version-1-6
    clear_lock git
  fi
  asdf local nim ref:version-1-6
}

teardown() {
  asdf plugin remove nim || true
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
  assert [ -f "${ASDF_NIM_VERSION_INSTALL_PATH}/nimble/pkgs/nimjson-1.2.8/nimjson.nimble" ]
  assert [ ! -x "./nimbledeps/bin/nimjson" ]
  assert [ ! -f "./nimbledeps/pkgs/nimjson-1.2.8/nimjson.nimble" ]

  # Assert that shim was created for package binary
  assert [ -f "${ASDF_DATA_DIR}/shims/nimjson" ]

  # Assert that correct nimjson is used
  assert [ -n "$(nimjson -v | grep ' version 1\.2\.8')" ]

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
  assert [ -f "./nimbledeps/pkgs/nimjson-1.2.8/nimjson.nimble" ]
  assert [ ! -x "${ASDF_NIM_VERSION_INSTALL_PATH}/nimble/bin/nimjson" ]
  assert [ ! -f "${ASDF_NIM_VERSION_INSTALL_PATH}/nimble/pkgs/nimjson-1.2.8/nimjson.nimble" ]

  # Assert that nim finds nimble packages
  echo "import nimjson" >"${ASDF_NIM_TEST_TEMP}/testnimble.nim"
  info "nim c --nimblePath:./nimbledeps/pkgs -r \"${ASDF_NIM_TEST_TEMP}/testnimble.nim\""
  nim c --nimblePath:./nimbledeps/pkgs -r "${ASDF_NIM_TEST_TEMP}/testnimble.nim"

  rm -rf nimbledeps
}
