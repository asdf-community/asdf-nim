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
  ASDF_INSTALL_VERSION="2.2.4"
  export ASDF_INSTALL_VERSION
  ASDF_INSTALL_TYPE="version"
  export ASDF_INSTALL_TYPE
  ASDF_INSTALL_PATH="${ASDF_DATA_DIR}/installs/nim/2.2.4"
  export ASDF_INSTALL_PATH
  ASDF_DOWNLOAD_PATH="${ASDF_DATA_DIR}/downloads/nim/2.2.4"
  export ASDF_DOWNLOAD_PATH
  ASDF_NIM_MOCK_GCC_DEFINES="#"
  export ASDF_NIM_MOCK_GCC_DEFINES

  # Add shims dir to PATH for testing
  PATH="${ASDF_DATA_DIR}/shims:$PATH"
  export PATH

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

# Mock asdf_nim_find_nightly_release_url for tests that don't have network access
# This returns the expected URL format for nightly releases without calling GitHub API
asdf_nim_find_nightly_release_url() {
  local desired_branch="$1"
  local platform_filename
  platform_filename="$(asdf_nim_get_platform_filename)"

  if [ -z "$platform_filename" ]; then
    return 0
  fi

  # Return the expected nightly URL format
  echo "https://github.com/nim-lang/nightlies/releases/download/latest-${desired_branch}/${platform_filename}"
}

# Mock asdf_nim_find_exact_nightly_url for tests that don't have network/git access
# This returns empty (no exact nightly match) to test fallback behavior
asdf_nim_find_exact_nightly_url() {
  # Return nothing - tests will verify fallback to source build
  return 0
}
