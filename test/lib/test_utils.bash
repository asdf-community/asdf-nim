setup_test() {
  export PROJECT_DIR="$(realpath $(dirname "$BATS_TEST_DIRNAME"))"

  # Hide pretty output
  ASDF_NIM_SILENT="yes"
  ASDF_NIM_TEST_TEMP="$(mktemp -t asdf-nim-utils-tests.XXXX -d)"

  # Mock ASDF vars
  ASDF_DATA_DIR="${ASDF_NIM_TEST_TEMP}/asdf"
  ASDF_INSTALL_VERSION="1.4.2"
  ASDF_INSTALL_TYPE="version"
  ASDF_INSTALL_PATH="${ASDF_DATA_DIR}/installs/nim/1.4.2"
  ASDF_DOWNLOAD_PATH="${ASDF_DATA_DIR}/downloads/nim/1.4.2"

  # Mock some other vars
  XDG_CONFIG_HOME="$ASDF_NIM_TEST_TEMP"
  ACTUAL_GITHUB_TOKEN="${GITHUB_TOKEN:-}"
  GITHUB_TOKEN=""
  GITHUB_USER=""
  GITHUB_PASSWORD=""

  # Make plugin files findable via ASDF_DATA_DIR
  mkdir -p "${ASDF_DATA_DIR}/plugins"
  ln -s "$PROJECT_DIR" "${ASDF_DATA_DIR}/plugins/nim"
  assert [ -f "${ASDF_DATA_DIR}/plugins/nim/share/unofficial-binaries.txt" ]
}

teardown_test() {
  rm -rf "$ASDF_NIM_TEST_TEMP"
}
