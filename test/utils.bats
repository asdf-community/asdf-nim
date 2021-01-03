#!/usr/bin/env bats

load ../node_modules/bats-support/load
load ../node_modules/bats-assert/load
load ../lib/utils
load ./lib/test_utils

setup() {
  setup_test
}

teardown() {
  teardown_test
}

@test "asdf_nim_log install" {
  asdf_nim_init "install"
  assert [ "$(asdf_nim_log)" = "${ASDF_DATA_DIR}/tmp/nim/1.4.2/install.log" ]
}

@test "asdf_nim_log download" {
  asdf_nim_init "download"
  assert [ "$(asdf_nim_log)" = "${ASDF_DATA_DIR}/tmp/nim/1.4.2/download.log" ]
}

@test "asdf_nim_init defaults" {
  unset ASDF_NIM_SILENT
  asdf_nim_init "download"

  # Configurable
  assert_equal "$ASDF_NIM_ACTION" "download"
  assert_equal "$ASDF_NIM_REMOVE_TEMP" "yes"
  assert_equal "$ASDF_NIM_REQUIRE_BINARY" "no"
  assert_equal "$ASDF_NIM_REQUIRE_BUILD_FROM_SOURCE" "no"
  assert_equal "$ASDF_NIM_DEBUG" "no"
  assert_equal "$ASDF_NIM_SILENT" "no"

  # Non-configurable
  assert_equal "$ASDF_NIM_TEMP" "${ASDF_DATA_DIR}/tmp/nim/1.4.2"
  assert_equal "$ASDF_NIM_DOWNLOAD_PATH" "${ASDF_NIM_TEMP}/download"
  assert_equal "$ASDF_NIM_INSTALL_PATH" "${ASDF_NIM_TEMP}/install"
}

@test "asdf_nim_init configuration" {
  ASDF_NIM_REMOVE_TEMP="no"
  ASDF_NIM_REQUIRE_BINARY="yes"
  ASDF_NIM_REQUIRE_BUILD_FROM_SOURCE="yes"
  ASDF_NIM_DEBUG="yes"
  ASDF_NIM_SILENT="yes"
  ASDF_NIM_TEMP="${ASDF_NIM_TEST_TEMP}/configured"

  asdf_nim_init "install"

  # Configurable
  assert_equal "$ASDF_NIM_ACTION" "install"
  assert_equal "$ASDF_NIM_REMOVE_TEMP" "no"
  assert_equal "$ASDF_NIM_REQUIRE_BINARY" "yes"
  assert_equal "$ASDF_NIM_REQUIRE_BUILD_FROM_SOURCE" "yes"
  assert_equal "$ASDF_NIM_DEBUG" "yes"
  assert_equal "$ASDF_NIM_SILENT" "yes"

  # Non-configurable
  assert_equal "$ASDF_NIM_TEMP" "${ASDF_DATA_DIR}/tmp/nim/1.4.2"
  assert_equal "$ASDF_NIM_DOWNLOAD_PATH" "${ASDF_NIM_TEMP}/download"
  assert_equal "$ASDF_NIM_INSTALL_PATH" "${ASDF_NIM_TEMP}/install"
}

@test "asdf_nim_cleanup" {
  original="$ASDF_NIM_TEMP"
  run asdf_nim_init && \
    asdf_nim_cleanup && \
    [ -z "$ASDF_NIM_TEMP" ] && \
    [ ! -d "$original" ] && \
    [ "$ASDF_NIM_INITIALIZED" = "no" ]
  assert_success
  # TODO ASDF_NIM_STDOUT/ASDF_NIM_STDERR redirection test
}

@test "asdf_nim_sort_versions" {
  expected="0.2.2 1.1.1 1.2.0 1.4.2"
  output="$(printf "1.4.2\n0.2.2\n1.1.1\n1.2.0" | asdf_nim_sort_versions | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_list_all_versions_contains_tagged_releases" {
  run asdf_nim_list_all_versions

  assert_line 0.10.2
  assert_line 0.11.0
  assert_line 0.11.2
  assert_line 0.12.0
  assert_line 0.13.0
  assert_line 0.14.0
  assert_line 0.14.2
  assert_line 0.15.0
  assert_line 0.15.2
  assert_line 0.16.0
  assert_line 0.17.0
  assert_line 0.17.2
  assert_line 0.18.0
  assert_line 0.19.0
  assert_line 0.19.2
  assert_line 0.19.4
  assert_line 0.19.6
  assert_line 0.20.0
  assert_line 0.20.2
  assert_line 0.8.14
  assert_line 0.9.0
  assert_line 0.9.2
  assert_line 0.9.4
  assert_line 0.9.6
  assert_line 1.0.0
  assert_line 1.0.10
  assert_line 1.0.2
  assert_line 1.0.4
  assert_line 1.0.6
  assert_line 1.0.8
  assert_line 1.2.0
  assert_line 1.2.2
  assert_line 1.2.4
  assert_line 1.2.6
  assert_line 1.2.8
  assert_line 1.4.0
  assert_line 1.4.2
}

@test "asdf_nim_list_all_versions_displays_in_order" {
  expected="$(asdf_nim_list_all_versions | asdf_nim_sort_versions)"
  run asdf_nim_list_all_versions
  assert_output "$expected"
}

@test "asdf_nim_normalize_os" {
  mkdir -p "${ASDF_NIM_TEST_TEMP}/bin"
  declare -A uname_outputs=(
    ["Darwin"]="macos"
    ["Linux"]="linux"
    ["MINGW"]="windows"
    ["Unknown"]="unknown"
  )
  for uname_output in "${!uname_outputs[@]}"; do
    # mock uname
    ASDF_NIM_MOCK_OS_NAME="${uname_output}"
    expected_os="${uname_outputs[$uname_output]}"
    output="$(asdf_nim_normalize_os)"
    assert_equal "$output" "$expected_os"
  done
}

@test "asdf_nim_exe_ext" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  expected=""
  output="$(asdf_nim_exe_ext)"
  assert_equal "$output" "$expected"

  ASDF_NIM_MOCK_OS_NAME="Darwin"
  expected=""
  output="$(asdf_nim_exe_ext)"
  assert_equal "$output" "$expected"

  ASDF_NIM_MOCK_OS_NAME="MINGW"
  expected=".exe"
  output="$(asdf_nim_exe_ext)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_normalize_arch_basic" {
  declare -A machine_names=(
    ["i386"]="i686"
    ["i486"]="i686"
    ["i586"]="i686"
    ["i686"]="i686"
    ["x86"]="i686"
    ["x32"]="i686"

    ["ppc64le"]="powerpc64le"
    ["unknown"]="unknown"
  )

  for machine_name in "${!machine_name[@]}"; do
    # mock uname
    ASDF_NIM_MOCK_MACHINE_NAME="$machine_name"
    expected_arch="${machine_names[$machine_name]}"
    output="$(asdf_nim_normalize_arch)"
    assert_equal "$output" "$expected_arch"
  done
}

@test "asdf_nim_normalize_arch_i686_x86_64_docker" {
  # In x86_64 docker hosts running x86 containers,
  # the kernel uname will show x86_64 so we have to properly detect using the
  # __amd64 gcc define.

  ASDF_NIM_MOCK_GCC_DEFINES="#"

  # Expect i686 when __amd64 is not defined
  ASDF_NIM_MOCK_MACHINE_NAME="x86_64"
  expected_arch="i686"
  output="$(asdf_nim_normalize_arch)"
  assert_equal "$output" "$expected_arch"

  ASDF_NIM_MOCK_MACHINE_NAME="amd64"
  expected_arch="i686"
  output="$(asdf_nim_normalize_arch)"
  assert_equal "$output" "$expected_arch"

  ASDF_NIM_MOCK_MACHINE_NAME="x64"
  expected_arch="i686"
  output="$(asdf_nim_normalize_arch)"
  assert_equal "$output" "$expected_arch"

  # Expect x86_64 only when __amd64 is defined
  ASDF_NIM_MOCK_GCC_DEFINES="#define __amd64 1"

  ASDF_NIM_MOCK_MACHINE_NAME="x86_64"
  expected_arch="x86_64"
  output="$(asdf_nim_normalize_arch)"
  assert_equal "$output" "$expected_arch"

  ASDF_NIM_MOCK_MACHINE_NAME="amd64"
  expected_arch="x86_64"
  output="$(asdf_nim_normalize_arch)"
  assert_equal "$output" "$expected_arch"

  ASDF_NIM_MOCK_MACHINE_NAME="x64"
  expected_arch="x86_64"
  output="$(asdf_nim_normalize_arch)"
  assert_equal "$output" "$expected_arch"
}

@test "asdf_nim_normalize_arch_arm32" {
  ASDF_NIM_MOCK_MACHINE_NAME="arm"
  for arm_version in {5..7}; do
    ASDF_NIM_MOCK_GCC_DEFINES="#define __ARM_ARCH ${arm_version}"
    expected_arch="armv${arm_version}"
    output="$(asdf_nim_normalize_arch)"
    assert_equal "$output" "$expected_arch"
  done
}

@test "asdf_nim_normalize_arch_arm64" {
  ASDF_NIM_MOCK_MACHINE_NAME="arm64"
  ASDF_NIM_MOCK_OS_NAME="Darwin"
  expected_arch="arm64"
  output="$(asdf_nim_normalize_arch)"
  assert_equal "$output" "$expected_arch"

  ASDF_NIM_MOCK_OS_NAME="Linux"
  expected_arch="aarch64"
  output="$(asdf_nim_normalize_arch)"
  assert_equal "$output" "$expected_arch"

  ASDF_NIM_MOCK_MACHINE_NAME="aarch64"
  ASDF_NIM_MOCK_OS_NAME="Linux"
  expected_arch="aarch64"
  output="$(asdf_nim_normalize_arch)"
  assert_equal "$output" "$expected_arch"
}

@test "asdf_nim_pkg_mgr" {
  mkdir -p "${ASDF_NIM_TEST_TEMP}/bin"
  ln -s "$(which which)" "${ASDF_NIM_TEST_TEMP}/bin"
  declare -a bin_names=(
    "brew"
    "apt-get"
    "apk"
    "pacman"
    "dnf"
    "choco"
  )
  for bin_name in "${bin_names[@]}"; do
    # mock package manager
    touch "${ASDF_NIM_TEST_TEMP}/bin/${bin_name}"
    chmod +x "${ASDF_NIM_TEST_TEMP}/bin/${bin_name}"
    output="$(PATH="${ASDF_NIM_TEST_TEMP}/bin" asdf_nim_pkg_mgr)"
    rm "${ASDF_NIM_TEST_TEMP}/bin/${bin_name}"
    assert_equal "$output" "$bin_name"
  done
}

@test "asdf_nim_list_deps_apt_get" {
  ASDF_NIM_MOCK_PKG_MGR="apt-get"
  expected="hub xz-utils build-essential"
  output="$(asdf_nim_list_deps | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_list_deps_apk" {
  ASDF_NIM_MOCK_PKG_MGR="apk"
  expected="hub xz build-base"
  output="$(asdf_nim_list_deps | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_list_deps_brew" {
  ASDF_NIM_MOCK_PKG_MGR="brew"
  expected="hub xz"
  output="$(asdf_nim_list_deps | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_list_deps_pacman" {
  ASDF_NIM_MOCK_PKG_MGR="pacman"
  expected="hub xz gcc"
  output="$(asdf_nim_list_deps | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_list_deps_dnf" {
  ASDF_NIM_MOCK_PKG_MGR="dnf"
  expected="hub xz gcc"
  output="$(asdf_nim_list_deps | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_list_deps_choco" {
  ASDF_NIM_MOCK_OS_NAME="MINGW"
  ASDF_NIM_MOCK_PKG_MGR="choco"
  expected="hub unzip mingw"
  output="$(asdf_nim_list_deps | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_install_deps_cmds_apt_get" {
  ASDF_NIM_MOCK_PKG_MGR="apt-get"
  expected="apt-get update -q -y && apt-get -qq install -y hub xz-utils build-essential"
  output="$(asdf_nim_install_deps_cmds)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_install_deps_cmds_apk" {
  ASDF_NIM_MOCK_PKG_MGR="apk"
  expected="apk add --update xz build-base && apk add --update --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing hub"
  output="$(asdf_nim_install_deps_cmds)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_install_deps_cmds_brew" {
  ASDF_NIM_MOCK_PKG_MGR="brew"
  expected="brew install hub xz"
  output="$(asdf_nim_install_deps_cmds)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_install_deps_cmds_pacman" {
  ASDF_NIM_MOCK_PKG_MGR="pacman"
  expected="pacman -Syu --noconfirm hub xz gcc"
  output="$(asdf_nim_install_deps_cmds)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_install_deps_cmds_dnf" {
  ASDF_NIM_MOCK_PKG_MGR="dnf"
  expected="dnf install -y hub xz gcc"
  output="$(asdf_nim_install_deps_cmds)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_install_deps_cmds_choco" {
  ASDF_NIM_MOCK_OS_NAME="MINGW"
  ASDF_NIM_MOCK_PKG_MGR="choco"
  expected="choco install --yes hub unzip mingw"
  output="$(asdf_nim_install_deps_cmds)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls_aarch64_linux_gnu" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_MACHINE_NAME="aarch64"
  asdf_nim_init "install"
  expected="https://github.com/elijahr/nim-builds/releases/download/nim-1.4.2--202012300913/nim-1.4.2--aarch64-linux-gnu.tar.xz https://nim-lang.org/download/nim-1.4.2.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls_aarch64_linux_musl" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_MACHINE_NAME="aarch64"
  ASDF_NIM_MOCK_IS_MUSL="yes"
  asdf_nim_init "install"
  expected="https://github.com/elijahr/nim-builds/releases/download/nim-1.4.2--202012300913/nim-1.4.2--aarch64-linux-musl.tar.xz https://nim-lang.org/download/nim-1.4.2.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls_armv5_linux_gnu" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_MACHINE_NAME="armv5"
  asdf_nim_init "install"
  expected="https://github.com/elijahr/nim-builds/releases/download/nim-1.4.2--202012300913/nim-1.4.2--armv5-linux-gnueabi.tar.xz https://nim-lang.org/download/nim-1.4.2.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls_armv6_linux_musl" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_MACHINE_NAME="armv6"
  ASDF_NIM_MOCK_IS_MUSL="yes"
  asdf_nim_init "install"
  expected="https://github.com/elijahr/nim-builds/releases/download/nim-1.4.2--202012300913/nim-1.4.2--armv6-linux-musleabihf.tar.xz https://nim-lang.org/download/nim-1.4.2.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls_armv7_linux_gnu" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_MACHINE_NAME="armv7"
  asdf_nim_init "install"
  expected="https://github.com/elijahr/nim-builds/releases/download/nim-1.4.2--202012300913/nim-1.4.2--armv7-linux-gnueabihf.tar.xz https://nim-lang.org/download/nim-1.4.2.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls_armv7_linux_musl" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_MACHINE_NAME="armv7"
  ASDF_NIM_MOCK_IS_MUSL="yes"
  asdf_nim_init "install"
  expected="https://github.com/elijahr/nim-builds/releases/download/nim-1.4.2--202012300913/nim-1.4.2--armv7-linux-musleabihf.tar.xz https://nim-lang.org/download/nim-1.4.2.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls_i686_linux_gnu" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_MACHINE_NAME="i686"
  asdf_nim_init "install"
  expected="https://nim-lang.org/download/nim-1.4.2-linux_x32.tar.xz https://nim-lang.org/download/nim-1.4.2.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls_powerpc64le_linux_gnu" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_MACHINE_NAME="powerpc64le"
  asdf_nim_init "install"
  expected="https://github.com/elijahr/nim-builds/releases/download/nim-1.4.2--202012300913/nim-1.4.2--powerpc64le-linux-gnu.tar.xz https://nim-lang.org/download/nim-1.4.2.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls_x86_64_linux_gnu" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_MACHINE_NAME="x86_64"
  ASDF_NIM_MOCK_GCC_DEFINES="#define __amd64 1"
  asdf_nim_init "install"
  expected="https://nim-lang.org/download/nim-1.4.2-linux_x64.tar.xz https://nim-lang.org/download/nim-1.4.2.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls_x86_64_linux_musl" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_MACHINE_NAME="x86_64"
  ASDF_NIM_MOCK_IS_MUSL="yes"
  ASDF_NIM_MOCK_GCC_DEFINES="#define __amd64 1"
  asdf_nim_init "install"
  expected="https://github.com/elijahr/nim-builds/releases/download/nim-1.4.2--202012300913/nim-1.4.2--x86_64-linux-musl.tar.xz https://nim-lang.org/download/nim-1.4.2.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls_x86_64_linux_musl_with_no_binaries_for_version_yet" {
  ASDF_INSTALL_VERSION="100.100.100"
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_MACHINE_NAME="x86_64"
  ASDF_NIM_MOCK_IS_MUSL="yes"
  ASDF_NIM_MOCK_GCC_DEFINES="#define __amd64 1"
  asdf_nim_init "install"
  expected="https://nim-lang.org/download/nim-100.100.100.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls_x86_64_linux_musl_with_no_binaries_for_version_yet_and_GITHUB_TOKEN" {
  if [ -z "$ACTUAL_GITHUB_TOKEN" ]; then
    skip "Test requires actual GITHUB_TOKEN"
  fi
  GITHUB_TOKEN="$ACTUAL_GITHUB_TOKEN"
  ASDF_INSTALL_VERSION="100.100.100"
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_MACHINE_NAME="x86_64"
  ASDF_NIM_MOCK_IS_MUSL="yes"
  ASDF_NIM_MOCK_GCC_DEFINES="#define __amd64 1"
  asdf_nim_init "install"
  expected="https://nim-lang.org/download/nim-100.100.100.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls_x86_64_macos_catalina_10_15_0" {
  ASDF_NIM_MOCK_OS_NAME="Darwin"
  ASDF_NIM_MOCK_MAC_OS_VERSION="10.15.0"
  ASDF_NIM_MOCK_MACHINE_NAME="x86_64"
  ASDF_NIM_MOCK_GCC_DEFINES="#define __amd64 1"
  asdf_nim_init "install"
  expected="https://github.com/elijahr/nim-builds/releases/download/nim-1.4.2--202012300913/nim-1.4.2--x86_64-macos-catalina.tar.xz https://nim-lang.org/download/nim-1.4.2.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls_x86_64_macos_catalina_11_0_0" {
  ASDF_NIM_MOCK_OS_NAME="Darwin"
  ASDF_NIM_MOCK_MAC_OS_VERSION="11.0.0"
  ASDF_NIM_MOCK_MACHINE_NAME="x86_64"
  ASDF_NIM_MOCK_GCC_DEFINES="#define __amd64 1"
  asdf_nim_init "install"
  expected="https://github.com/elijahr/nim-builds/releases/download/nim-1.4.2--202012300913/nim-1.4.2--x86_64-macos-catalina.tar.xz https://nim-lang.org/download/nim-1.4.2.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls_source_url_macos" {
  ASDF_NIM_MOCK_OS_NAME="Darwin"
  ASDF_INSTALL_VERSION="100.100.100"
  asdf_nim_init "install"
  expected="https://nim-lang.org/download/nim-100.100.100.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_assert_github_auth_no_auth" {
  asdf_nim_init "install"
  run asdf_nim_assert_github_auth
  assert_failure
}

@test "asdf_nim_assert_github_auth_GITHUB_USER_no_GITHUB_PASSWORD" {
  asdf_nim_init "install"
  GITHUB_USER="elijahr"
  run asdf_nim_assert_github_auth
  assert_failure
}

@test "asdf_nim_assert_github_auth_GITHUB_USER_and_GITHUB_PASSWORD" {
  asdf_nim_init "install"
  GITHUB_USER="elijahr"
  GITHUB_PASSWORD="elijahr"
  run asdf_nim_assert_github_auth
  assert_success
}

@test "asdf_nim_assert_github_auth_GITHUB_TOKEN" {
  asdf_nim_init "install"
  GITHUB_TOKEN="elijahr"
  run asdf_nim_assert_github_auth
  assert_success
}

@test "asdf_nim_assert_github_auth_XDG_CONFIG_HOME_hub" {
  asdf_nim_init "install"
  touch "${XDG_CONFIG_HOME}/hub"
  run asdf_nim_assert_github_auth
  assert_success
}

@test "asdf_nim_needs_download_missing_ASDF_DOWNLOAD_PATH" {
  asdf_nim_init "install"
  run asdf_nim_needs_download
  assert_output "yes"
}

@test "asdf_nim_needs_download_with_ASDF_DOWNLOAD_PATH" {
  asdf_nim_init "install"
  mkdir -p "$ASDF_DOWNLOAD_PATH"
  run asdf_nim_needs_download
  assert_output "no"
}

@test "asdf_nim_download_ref" {
  export ASDF_INSTALL_TYPE="ref"
  export ASDF_INSTALL_VERSION="HEAD"
  asdf_nim_init "download"
  run asdf_nim_download
  assert_success
  assert [ -d "${ASDF_DOWNLOAD_PATH}/.git" ]
  assert [ -f "${ASDF_DOWNLOAD_PATH}/koch.nim" ]
}

@test "asdf_nim_download_version" {
  ASDF_DOWNLOAD_PATH="${ASDF_DATA_DIR}/downloads/nim/${ASDF_INSTALL_VERSION}"
  asdf_nim_init "download"
  run asdf_nim_download
  assert_success
  refute [ -d "${ASDF_DOWNLOAD_PATH}/.git" ]
  assert [ -f "${ASDF_DOWNLOAD_PATH}/koch.nim" ]
}

@test "asdf_nim_needs_build_unix" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  asdf_nim_init "install"
  run asdf_nim_needs_build
  assert_success
  assert_output "yes"
  mkdir -p "${ASDF_DOWNLOAD_PATH}/bin"
  run asdf_nim_needs_build
  assert_success
  assert_output "yes"
  touch "${ASDF_DOWNLOAD_PATH}/bin/nim"
  run asdf_nim_needs_build
  assert_success
  assert_output "yes"
  touch "${ASDF_DOWNLOAD_PATH}/bin/nimgrep"
  run asdf_nim_needs_build
  assert_success
  assert_output "yes"
  touch "${ASDF_DOWNLOAD_PATH}/bin/nimble"
  run asdf_nim_needs_build
  assert_success
  assert_output "yes"
  touch "${ASDF_DOWNLOAD_PATH}/install.sh"
  run asdf_nim_needs_build
  assert_success
  assert_output "no"
  ASDF_NIM_REQUIRE_BUILD_FROM_SOURCE="yes"
  run asdf_nim_needs_build
  assert_success
  assert_output "yes"
}

@test "asdf_nim_needs_build_windows" {
  ASDF_NIM_MOCK_OS_NAME="MINGW"
  asdf_nim_init "install"
  run asdf_nim_needs_build
  assert_success
  assert_output "yes"
  mkdir -p "${ASDF_DOWNLOAD_PATH}/bin"
  run asdf_nim_needs_build
  assert_success
  assert_output "yes"
  touch "${ASDF_DOWNLOAD_PATH}/bin/nim.exe"
  run asdf_nim_needs_build
  assert_success
  assert_output "yes"
  touch "${ASDF_DOWNLOAD_PATH}/bin/nimgrep.exe"
  run asdf_nim_needs_build
  assert_success
  assert_output "yes"
  touch "${ASDF_DOWNLOAD_PATH}/bin/nimble.exe"
  run asdf_nim_needs_build
  assert_success
  assert_output "no"
  ASDF_NIM_REQUIRE_BUILD_FROM_SOURCE="yes"
  run asdf_nim_needs_build
  assert_success
  assert_output "yes"
}

# @test "asdf_nim_build" {
#   skip "TODO, but covered by integration tests & CI"
# }

# @test "asdf_nim_install" {
#   skip "TODO, but covered by integration tests & CI"
# }
