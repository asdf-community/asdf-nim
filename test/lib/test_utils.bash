export PROJECT_DIR
PROJECT_DIR="$(realpath "$(dirname "$BATS_TEST_DIRNAME")")"

get_lock() {
  local lock_path
  mkdir -p "${PROJECT_DIR}/.tmp"
  lock_path="${PROJECT_DIR}/.tmp/${1}.lock"
  # shellcheck disable=SC2188
  while ! {
    set -C
    2>/dev/null >"$lock_path"
  }; do
    sleep 0.01
  done
}

clear_lock() {
  local lock_path
  mkdir -p "${PROJECT_DIR}/.tmp"
  lock_path="${PROJECT_DIR}/.tmp/${1}.lock"
  rm -f "$lock_path"
}

setup_test() {
  # Hide pretty output
  ASDF_NIM_SILENT="yes"
  export ASDF_NIM_SILENT

  ASDF_NIM_TEST_TEMP="$(mktemp -t asdf-nim-utils-tests.XXXX -d)"
  export ASDF_NIM_TEST_TEMP

  # Mock ASDF vars
  ASDF_DATA_DIR="${ASDF_NIM_TEST_TEMP}/asdf"
  export ASDF_DATA_DIR
  ASDF_INSTALL_VERSION="1.6.0"
  export ASDF_INSTALL_VERSION
  ASDF_INSTALL_TYPE="version"
  export ASDF_INSTALL_TYPE
  ASDF_INSTALL_PATH="${ASDF_DATA_DIR}/installs/nim/1.6.0"
  export ASDF_INSTALL_PATH
  ASDF_DOWNLOAD_PATH="${ASDF_DATA_DIR}/downloads/nim/1.6.0"
  export ASDF_DOWNLOAD_PATH
  ASDF_NIM_MOCK_GCC_DEFINES="#"
  export ASDF_NIM_MOCK_GCC_DEFINES

  # Mock some other vars
  export XDG_CONFIG_HOME
  XDG_CONFIG_HOME="$ASDF_NIM_TEST_TEMP"
  export ACTUAL_GITHUB_TOKEN
  ACTUAL_GITHUB_TOKEN="${GITHUB_TOKEN-}"
  export GITHUB_TOKEN
  GITHUB_TOKEN=""
  export GITHUB_USER
  GITHUB_USER=""
  export GITHUB_PASSWORD
  GITHUB_PASSWORD=""

  # Make plugin files findable via ASDF_DATA_DIR
  mkdir -p "${ASDF_DATA_DIR}/plugins"
  ln -s "$PROJECT_DIR" "${ASDF_DATA_DIR}/plugins/nim"
}

teardown_test() {
  rm -rf "$ASDF_NIM_TEST_TEMP"
}
