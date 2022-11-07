#!/usr/bin/env bats

# shellcheck disable=SC2030,SC2031,SC2034,SC2230,SC2190

load ../node_modules/bats-support/load.bash
load ../node_modules/bats-assert/load.bash
load ../lib/utils
load ./lib/test_utils

setup() {
  setup_test
}

teardown() {
  teardown_test
}

@test "asdf_nim_log__install" {
  asdf_nim_init "install"
  assert [ "$(asdf_nim_log)" = "${ASDF_DATA_DIR}/tmp/nim/1.6.0/install.log" ]
}

@test "asdf_nim_log__download" {
  asdf_nim_init "download"
  assert [ "$(asdf_nim_log)" = "${ASDF_DATA_DIR}/tmp/nim/1.6.0/download.log" ]
}

@test "asdf_nim_init__defaults" {
  unset ASDF_NIM_SILENT
  asdf_nim_init "download"

  # Configurable
  assert_equal "$ASDF_NIM_ACTION" "download"
  assert_equal "$ASDF_NIM_REMOVE_TEMP" "yes"
  assert_equal "$ASDF_NIM_DEBUG" "no"
  assert_equal "$ASDF_NIM_SILENT" "no"

  # Non-configurable
  assert_equal "$ASDF_NIM_TEMP" "${ASDF_DATA_DIR}/tmp/nim/1.6.0"
  assert_equal "$ASDF_NIM_DOWNLOAD_PATH" "${ASDF_NIM_TEMP}/download"
  assert_equal "$ASDF_NIM_INSTALL_PATH" "${ASDF_NIM_TEMP}/install"
}

@test "asdf_nim_init__configuration" {
  ASDF_NIM_REMOVE_TEMP="no"
  ASDF_NIM_DEBUG="yes"
  ASDF_NIM_SILENT="yes"
  ASDF_NIM_TEMP="${ASDF_NIM_TEST_TEMP}/configured"

  asdf_nim_init "install"

  # Configurable
  assert_equal "$ASDF_NIM_ACTION" "install"
  assert_equal "$ASDF_NIM_REMOVE_TEMP" "no"
  assert_equal "$ASDF_NIM_DEBUG" "yes"
  assert_equal "$ASDF_NIM_SILENT" "yes"

  # Non-configurable
  assert_equal "$ASDF_NIM_TEMP" "${ASDF_DATA_DIR}/tmp/nim/1.6.0"
  assert_equal "$ASDF_NIM_DOWNLOAD_PATH" "${ASDF_NIM_TEMP}/download"
  assert_equal "$ASDF_NIM_INSTALL_PATH" "${ASDF_NIM_TEMP}/install"
}

@test "asdf_nim_cleanup" {
  original="$ASDF_NIM_TEMP"
  run asdf_nim_init &&
    asdf_nim_cleanup &&
    [ -z "$ASDF_NIM_TEMP" ] &&
    [ ! -d "$original" ] &&
    [ "$ASDF_NIM_INITIALIZED" = "no" ]
  assert_success
  # TODO ASDF_NIM_STDOUT/ASDF_NIM_STDERR redirection test
}

@test "asdf_nim_sort_versions" {
  expected="0.2.2 1.1.1 1.2.0 1.6.0"
  output="$(printf "1.6.0\n0.2.2\n1.1.1\n1.2.0" | asdf_nim_sort_versions | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_list_all_versions__contains_tagged_releases" {
  run asdf_nim_list_all_versions

  # Can't hardcode the ever-growing list of releases, so just check for a few known ones
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
  assert_line 1.6.0
}

@test "asdf_nim_list_all_versions__displays_in_order" {
  assert [ "$(asdf_nim_list_all_versions | grep -Fn '1.6.0' | sed 's/:.*//')" -gt "$(asdf_nim_list_all_versions | grep -Fn '1.4.8' | sed 's/:.*//')" ]
  assert [ "$(asdf_nim_list_all_versions | grep -Fn '1.6.2' | sed 's/:.*//')" -gt "$(asdf_nim_list_all_versions | grep -Fn '1.6.0' | sed 's/:.*//')" ]
  assert [ "$(asdf_nim_list_all_versions | grep -Fn '1.6.4' | sed 's/:.*//')" -gt "$(asdf_nim_list_all_versions | grep -Fn '1.6.2' | sed 's/:.*//')" ]
  assert [ "$(asdf_nim_list_all_versions | grep -Fn '1.6.6' | sed 's/:.*//')" -gt "$(asdf_nim_list_all_versions | grep -Fn '1.6.4' | sed 's/:.*//')" ]
  assert [ "$(asdf_nim_list_all_versions | grep -Fn '1.6.8' | sed 's/:.*//')" -gt "$(asdf_nim_list_all_versions | grep -Fn '1.6.6' | sed 's/:.*//')" ]
}

@test "asdf_nim_normalize_os" {
  mkdir -p "${ASDF_NIM_TEST_TEMP}/bin"
  declare -A uname_outputs=(
    ["Darwin"]="macos"
    ["Linux"]="linux"
    ["MINGW"]="windows" # not actually supported by asdf?
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

@test "asdf_nim_normalize_arch__basic" {
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

@test "asdf_nim_normalize_arch__i686__x86_64_docker" {
  # In x86_64 docker hosts running x86 containers,
  # the kernel uname will show x86_64 so we have to properly detect using the
  # __amd64 gcc define.

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

@test "asdf_nim_normalize_arch__arm32__via_gcc" {
  ASDF_NIM_MOCK_MACHINE_NAME="arm"
  for arm_version in {5..7}; do
    ASDF_NIM_MOCK_GCC_DEFINES="#define __ARM_ARCH ${arm_version}"
    expected_arch="armv${arm_version}"
    output="$(asdf_nim_normalize_arch)"
    assert_equal "$output" "$expected_arch"
  done
}

@test "asdf_nim_normalize_arch__armel__via_dpkg" {
  ASDF_NIM_MOCK_MACHINE_NAME="arm"
  ASDF_NIM_MOCK_DPKG_ARCHITECTURE="armel"
  expected_arch="armv5"
  output="$(asdf_nim_normalize_arch)"
  assert_equal "$output" "$expected_arch"
}

@test "asdf_nim_normalize_arch__armhf__via_dpkg" {
  ASDF_NIM_MOCK_MACHINE_NAME="arm"
  ASDF_NIM_MOCK_DPKG_ARCHITECTURE="armhf"
  expected_arch="armv7"
  output="$(asdf_nim_normalize_arch)"
  assert_equal "$output" "$expected_arch"
}

@test "asdf_nim_normalize_arch__arm__no_dpkg_no_gcc" {
  ASDF_NIM_MOCK_MACHINE_NAME="arm"
  expected_arch="armv5"
  output="$(asdf_nim_normalize_arch)"
  assert_equal "$output" "$expected_arch"
}

@test "asdf_nim_normalize_arch__armv7l__no_dpkg_no_gcc" {
  ASDF_NIM_MOCK_MACHINE_NAME="armv7l"
  expected_arch="armv7"
  output="$(asdf_nim_normalize_arch)"
  assert_equal "$output" "$expected_arch"
}

@test "asdf_nim_normalize_arch__arm64" {
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
  declare -a bin_names=(
    "brew"
    "apt-get"
    "apk"
    "pacman"
    "dnf"
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

@test "asdf_nim_list_deps__apt_get" {
  ASDF_NIM_MOCK_PKG_MGR="apt-get"
  expected="xz-utils build-essential"
  output="$(asdf_nim_list_deps | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_list_deps__apk" {
  ASDF_NIM_MOCK_PKG_MGR="apk"
  expected="xz build-base"
  output="$(asdf_nim_list_deps | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_list_deps__brew" {
  ASDF_NIM_MOCK_PKG_MGR="brew"
  expected="xz"
  output="$(asdf_nim_list_deps | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_list_deps__pacman" {
  ASDF_NIM_MOCK_PKG_MGR="pacman"
  expected="xz gcc"
  output="$(asdf_nim_list_deps | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_list_deps__dnf" {
  ASDF_NIM_MOCK_PKG_MGR="dnf"
  expected="xz gcc"
  output="$(asdf_nim_list_deps | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_install_deps_cmds__apt_get" {
  ASDF_NIM_MOCK_PKG_MGR="apt-get"
  expected="apt-get update -q -y && apt-get -qq install -y xz-utils build-essential"
  output="$(asdf_nim_install_deps_cmds)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_install_deps_cmds__apk" {
  ASDF_NIM_MOCK_PKG_MGR="apk"
  expected="apk add --update xz build-base"
  output="$(asdf_nim_install_deps_cmds)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_install_deps_cmds__brew" {
  ASDF_NIM_MOCK_PKG_MGR="brew"
  expected="brew install xz"
  output="$(asdf_nim_install_deps_cmds)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_install_deps_cmds__pacman" {
  ASDF_NIM_MOCK_PKG_MGR="pacman"
  expected="pacman -Syu --noconfirm xz gcc"
  output="$(asdf_nim_install_deps_cmds)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_install_deps_cmds__dnf" {
  ASDF_NIM_MOCK_PKG_MGR="dnf"
  expected="dnf install -y xz gcc"
  output="$(asdf_nim_install_deps_cmds)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls__stable__linux__x86_64__glibc" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_IS_MUSL="no"
  ASDF_NIM_MOCK_MACHINE_NAME="x86_64"
  ASDF_NIM_MOCK_GCC_DEFINES="#define __amd64 1"
  asdf_nim_init "install"
  expected="https://nim-lang.org/download/nim-1.6.0-linux_x64.tar.xz https://nim-lang.org/download/nim-1.6.0.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls__stable__linux__i686__glibc" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_IS_MUSL="no"
  ASDF_NIM_MOCK_MACHINE_NAME="i686"
  asdf_nim_init "install"
  expected="https://nim-lang.org/download/nim-1.6.0-linux_x32.tar.xz https://nim-lang.org/download/nim-1.6.0.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls__stable__linux__other_archs__glibc" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_IS_MUSL="no"
  declare -a machine_names=(
    "aarch64"
    "armv5"
    "armv6"
    "armv7"
    "powerpc64le"
  )
  for machine_name in "${machine_names[@]}"; do
    ASDF_NIM_MOCK_MACHINE_NAME="$machine_name"
    asdf_nim_init "install"
    expected="https://nim-lang.org/download/nim-1.6.0.tar.xz"
    output="$(asdf_nim_download_urls | xargs)"
    assert_equal "$output" "$expected"
  done
}

@test "asdf_nim_download_urls__stable__linux__x86_64__musl" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_IS_MUSL="yes"
  ASDF_NIM_MOCK_MACHINE_NAME="x86_64"
  ASDF_NIM_MOCK_GCC_DEFINES="#define __amd64 1"
  asdf_nim_init "install"
  expected="https://nim-lang.org/download/nim-1.6.0.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls__stable__linux__other_archs__musl" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_IS_MUSL="yes"
  declare -a machine_names=(
    "aarch64"
    "armv5"
    "armv6"
    "armv7"
    "i686"
    "powerpc64le"
  )
  for machine_name in "${machine_names[@]}"; do
    ASDF_NIM_MOCK_MACHINE_NAME="$machine_name"
    asdf_nim_init "install"
    expected="https://nim-lang.org/download/nim-1.6.0.tar.xz"
    output="$(asdf_nim_download_urls | xargs)"
    assert_equal "$output" "$expected"
  done
}

@test "asdf_nim_download_urls__stable__macos__x86_64" {
  ASDF_NIM_MOCK_OS_NAME="Darwin"
  ASDF_NIM_MOCK_MACHINE_NAME="x86_64"
  ASDF_NIM_MOCK_GCC_DEFINES="#define __amd64 1"
  asdf_nim_init "install"
  expected="https://nim-lang.org/download/nim-1.6.0.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls__stable__macos__arm64" {
  ASDF_NIM_MOCK_OS_NAME="Darwin"
  ASDF_NIM_MOCK_MACHINE_NAME="arm64"
  asdf_nim_init "install"
  expected="https://nim-lang.org/download/nim-1.6.0.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls__stable__netbsd__x86_64" {
  ASDF_NIM_MOCK_OS_NAME="NetBSD"
  ASDF_NIM_MOCK_MACHINE_NAME="x86_64"
  ASDF_NIM_MOCK_GCC_DEFINES="#define __amd64 1"
  asdf_nim_init "install"
  expected="https://nim-lang.org/download/nim-1.6.0.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls__nightly__linux__x86_64__musl" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_IS_MUSL="yes"
  ASDF_NIM_MOCK_MACHINE_NAME="x86_64"
  ASDF_NIM_MOCK_GCC_DEFINES="#define __amd64 1"
  ASDF_INSTALL_TYPE="ref"
  ASDF_INSTALL_VERSION="version-1-6"
  asdf_nim_init "install"
  expected=""
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls__nightly__linux__other_archs__musl" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_IS_MUSL="yes"
  ASDF_INSTALL_TYPE="ref"
  ASDF_INSTALL_VERSION="version-1-6"
  declare -a machine_names=(
    "aarch64"
    "armv5"
    "armv6"
    "armv7"
    "i686"
    "powerpc64le"
  )
  for machine_name in "${machine_names[@]}"; do
    ASDF_NIM_MOCK_MACHINE_NAME="$machine_name"
    asdf_nim_init "install"
    expected=""
    output="$(asdf_nim_download_urls | xargs)"
    assert_equal "$output" "$expected"
  done
}

@test "asdf_nim_download_urls__nightly__linux__x86_64__glibc" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_IS_MUSL="no"
  ASDF_NIM_MOCK_MACHINE_NAME="x86_64"
  ASDF_NIM_MOCK_GCC_DEFINES="#define __amd64 1"
  ASDF_INSTALL_TYPE="ref"
  ASDF_INSTALL_VERSION="version-1-6"
  asdf_nim_init "install"
  expected="https://github.com/nim-lang/nightlies/releases/download/latest-version-1-6/linux_x64.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls__nightly__linux__i686__glibc" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_IS_MUSL="no"
  ASDF_NIM_MOCK_MACHINE_NAME="i686"
  ASDF_INSTALL_TYPE="ref"
  ASDF_INSTALL_VERSION="version-1-6"
  asdf_nim_init "install"
  expected="https://github.com/nim-lang/nightlies/releases/download/latest-version-1-6/linux_x32.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls__nightly__linux__other_archs__glibc" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_IS_MUSL="no"
  ASDF_INSTALL_TYPE="ref"
  ASDF_INSTALL_VERSION="version-1-6"
  declare -a machine_names=(
    "armv5"
    "armv6"
    "powerpc64le"
  )
  for machine_name in "${machine_names[@]}"; do
    ASDF_NIM_MOCK_MACHINE_NAME="$machine_name"
    asdf_nim_init "install"
    expected=""
    output="$(asdf_nim_download_urls | xargs)"
    assert_equal "$output" "$expected"
  done
}

@test "asdf_nim_download_urls__nightly__linux__armv7__glibc" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_MACHINE_NAME="armv7"
  ASDF_INSTALL_TYPE="ref"
  ASDF_INSTALL_VERSION="version-1-6"
  asdf_nim_init "install"
  expected="https://github.com/nim-lang/nightlies/releases/download/latest-version-1-6/linux_armv7l.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls__nightly__linux__aarch64__glibc" {
  ASDF_NIM_MOCK_OS_NAME="Linux"
  ASDF_NIM_MOCK_MACHINE_NAME="aarch64"
  ASDF_INSTALL_TYPE="ref"
  ASDF_INSTALL_VERSION="devel"
  asdf_nim_init "install"
  expected="https://github.com/nim-lang/nightlies/releases/download/latest-devel/linux_arm64.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls__nightly__macos__x86_64" {
  ASDF_NIM_MOCK_OS_NAME="Darwin"
  ASDF_NIM_MOCK_MACHINE_NAME="x86_64"
  ASDF_NIM_MOCK_GCC_DEFINES="#define __amd64 1"
  ASDF_INSTALL_TYPE="ref"
  ASDF_INSTALL_VERSION="version-1-6"
  asdf_nim_init "install"
  expected="https://github.com/nim-lang/nightlies/releases/download/latest-version-1-6/macosx_x64.tar.xz"
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls__nightly__macos__arm64" {
  ASDF_NIM_MOCK_OS_NAME="Darwin"
  ASDF_NIM_MOCK_MACHINE_NAME="arm64"
  ASDF_INSTALL_TYPE="ref"
  ASDF_INSTALL_VERSION="version-1-6"
  asdf_nim_init "install"
  expected=""
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_download_urls__nightly__netbsd__x86_64" {
  ASDF_NIM_MOCK_OS_NAME="NetBSD"
  ASDF_NIM_MOCK_MACHINE_NAME="x86_64"
  ASDF_NIM_MOCK_GCC_DEFINES="#define __amd64 1"
  ASDF_INSTALL_TYPE="ref"
  ASDF_INSTALL_VERSION="version-1-6"
  asdf_nim_init "install"
  expected=""
  output="$(asdf_nim_download_urls | xargs)"
  assert_equal "$output" "$expected"
}

@test "asdf_nim_needs_download__missing_ASDF_DOWNLOAD_PATH" {
  asdf_nim_init "install"
  run asdf_nim_needs_download
  assert_output "yes"
}

@test "asdf_nim_needs_download__with_ASDF_DOWNLOAD_PATH" {
  asdf_nim_init "install"
  mkdir -p "$ASDF_DOWNLOAD_PATH"
  run asdf_nim_needs_download
  assert_output "no"
}

@test "asdf_nim_download__ref" {
  export ASDF_INSTALL_TYPE
  ASDF_INSTALL_TYPE="ref"
  export ASDF_INSTALL_VERSION
  ASDF_INSTALL_VERSION="HEAD"
  asdf_nim_init "download"
  run asdf_nim_download
  assert_success
  assert [ -d "${ASDF_DOWNLOAD_PATH}/.git" ]
  assert [ -f "${ASDF_DOWNLOAD_PATH}/koch.nim" ]
}

@test "asdf_nim_download__version" {
  ASDF_DOWNLOAD_PATH="${ASDF_DATA_DIR}/downloads/nim/${ASDF_INSTALL_VERSION}"
  asdf_nim_init "download"
  run asdf_nim_download
  assert_success
  refute [ -d "${ASDF_DOWNLOAD_PATH}/.git" ]
  assert [ -f "${ASDF_DOWNLOAD_PATH}/koch.nim" ]
}

# @test "asdf_nim_build" {
#   skip "TODO, but covered by integration tests & CI"
# }

# @test "asdf_nim_install" {
#   skip "TODO, but covered by integration tests & CI"
# }
