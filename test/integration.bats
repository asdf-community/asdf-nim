#!/usr/bin/env bats

load ../node_modules/bats-support/load
load ../node_modules/bats-assert/load

setup_file() {
  export PROJECT_DIR="$(realpath $(dirname "$BATS_TEST_DIRNAME"))"
  cd "$PROJECT_DIR"

  export ASDF_NIM_TEST_TEMP="$(mktemp -t asdf-nim-integration-tests.XXXX -d)"
  export ASDF_DATA_DIR="${ASDF_NIM_TEST_TEMP}/asdf"
  mkdir -p "$ASDF_DATA_DIR"
  git clone --branch=v0.8.0 --depth=1 https://github.com/asdf-vm/asdf.git "$ASDF_DATA_DIR"
  mkdir -p "$ASDF_DATA_DIR/plugins"
  . "${ASDF_DATA_DIR}/asdf.sh"
}

teardown_file() {
  rm -rf "${ASDF_NIM_TEST_TEMP}"
  cd -
}

teardown() {
  asdf plugin remove nim || true
}

info() {
  echo "# $@ …" >&3
}

@test "nimble configuration" {
  # `asdf plugin add nim .` would only install from git HEAD.
  # So, we mock an installation via a symlink.
  # This makes it easier to run tests while developing.
  ln -s "$PROJECT_DIR" "${ASDF_DATA_DIR}/plugins/nim"

  info "asdf install nim 1.4.2"
  asdf install nim 1.4.2
  asdf local nim 1.4.2

  ASDF_INSTALL_PATH="${ASDF_DATA_DIR}/installs/nim/1.4.2"

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
  assert [ -n "$(which nimjson)" ]

  # Assert that nim finds nimble packages
  echo "import nimjson" >"${ASDF_NIM_TEST_TEMP}/testnimble.nim"
  info "nim c -r \"${ASDF_NIM_TEST_TEMP}/testnimble.nim\""
  nim c -r "${ASDF_NIM_TEST_TEMP}/testnimble.nim"
}
