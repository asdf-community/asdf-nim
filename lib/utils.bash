#!/usr/bin/env bash

# Constants
SOURCE_REPO="https://github.com/nim-lang/Nim.git"
SOURCE_URL="https://nim-lang.org/download/nim-{version}.tar.xz"
LINUX_X64_URL="https://nim-lang.org/download/nim-{version}-linux_x64.tar.xz"
LINUX_X32_URL="https://nim-lang.org/download/nim-{version}-linux_x32.tar.xz"
WINDOWS_X64_URL="https://nim-lang.org/download/nim-{version}_x64.zip"
WINDOWS_X32_URL="https://nim-lang.org/download/nim-{version}_x32.zip"
WINDOWS_DLLS_URL="https://nim-lang.org/download/dlls.zip"
NIM_BUILDS_REPO="https://github.com/elijahr/nim-builds.git"
NIM_ARGS=("--parallelBuild:${ASDF_CONCURRENCY:-0}" "-d:release") # Args to pass to koch/nim

ASDF_NIM_EXIT_STATUS_NEEDS_DOWNLOAD=2

normpath() {
  # Remove all /./ sequences.
  local path="${1//\/.\//\/}"
  # Remove dir/.. sequences.
  while [[ "$path" =~ ([^/][^/]*/\.\./?) ]]; do
    path="${path/${BASH_REMATCH[0]}/}"
  done
  echo "$path" | sed 's/\/$//'
}

# Ensure ASDF_DATA_DIR has a value
ASDF_DATA_DIR="${ASDF_DATA_DIR:-${ASDF_DIR:-$(normpath "${ASDF_INSTALL_PATH}/../../..")}}"

# Create the temp directories used by the download/build/install functions.
asdf_nim_init() {
  export ASDF_NIM_ACTION="$1"

  # Configuration options
  export ASDF_NIM_REMOVE_TEMP="${ASDF_NIM_REMOVE_TEMP:-yes}"                            # If no, asdf-nim's temporary directory won't be deleted on exit
  export ASDF_NIM_REQUIRE_BINARY="${ASDF_NIM_REQUIRE_BINARY:-no}"                       # If yes, Nim will never be built from source. The script will exit with status 1 if a binary cannot be found.
  export ASDF_NIM_REQUIRE_BUILD_FROM_SOURCE="${ASDF_NIM_REQUIRE_BUILD_FROM_SOURCE:-no}" # If yes, Nim will always be built from source, even if a binary is available.
  export ASDF_NIM_DEBUG="${ASDF_NIM_DEBUG:-no}"                                         # If yes, extra information will be logged to the console and every command executed will be logged to the logfile.
  export ASDF_NIM_STDOUT="${ASDF_NIM_STDOUT:-1}"                                        # The file descriptor where the script's standard output should be directed.
  export ASDF_NIM_STDERR="${ASDF_NIM_STDERR:-2}"                                        # The file descriptor where the script's standard error output should be directed.
  export ASDF_NIM_SILENT="${ASDF_NIM_SILENT:-no}"                                       # If yes, asdf-nim will not echo build steps to stdout.
  # End configuration options

  export ASDF_NIM_TEMP="${ASDF_DATA_DIR}/tmp/nim/${ASDF_INSTALL_VERSION}"
  export ASDF_NIM_DOWNLOAD_PATH="${ASDF_NIM_TEMP}/download" # Temporary directory where downloads are placed
  export ASDF_NIM_INSTALL_PATH="${ASDF_NIM_TEMP}/install"   # Temporary directory where installation is prepared

  mkdir -p "$ASDF_NIM_TEMP"
  rm -f "$(asdf_nim_log)"

  if [ "$ASDF_NIM_DEBUG" = "yes" ]; then
    out
    out "# Environment:"
    out
    env | grep "^ASDF_" | sort | xargs printf "#  %s\n" 1>&$ASDF_NIM_STDOUT 2>&$ASDF_NIM_STDERR || true
  fi
}

asdf_nim_init_traps() {
  # Exit handlers
  trap 'ASDF_NIM_EXIT_STATUS=$?; asdf_nim_on_exit; exit $ASDF_NIM_EXIT_STATUS' EXIT
  trap 'trap - HUP; ASDF_NIM_SIGNAL=SIGHUP; kill -HUP $$' HUP
  trap 'trap - INT; ASDF_NIM_SIGNAL=SIGINT; kill -INT $$' INT
  trap 'trap - TERM; ASDF_NIM_SIGNAL=SIGTERM; kill -TERM $$' TERM
}

out() {
  # To screen
  if [ "$ASDF_NIM_SILENT" = "no" ]; then
    echo "$@" 1>&$ASDF_NIM_STDOUT 2>&$ASDF_NIM_STDERR
  fi
}

outf() {
  # To screen
  if [ "$ASDF_NIM_SILENT" = "no" ]; then
    printf "$@" 1>&$ASDF_NIM_STDOUT 2>&$ASDF_NIM_STDERR
  fi
}

asdf_nim_on_exit() {
  asdf_nim_cleanup_asdf_install_path() {
    if [ -d "$ASDF_INSTALL_PATH" ]; then
      out "# Cleaning up install directory…"
      rm -rf "$ASDF_INSTALL_PATH"
    fi
  }

  asdf_nim_cleanup_asdf_download_path() {
    if [ -d "$ASDF_DOWNLOAD_PATH" ]; then
      if [ "${1:-}" = "force" ]; then
        # Force delete
        out "# Cleaning up download directory…"
        rm -rf "$ASDF_DOWNLOAD_PATH"
      else
        # asdf will delete this folder depending on --keep-download or
        # always_keep_download flag, so respect that by not deleting here;
        # however, asdf uses `rm -r` instead of `rm -rf` which fails to delete
        # protected git objects. So we simply chmod the git objects so they
        # can be deleted if asdf decides to delete.
        out "# Making download directory removable…"
        chmod -R 700 "$ASDF_DOWNLOAD_PATH"
      fi
    fi
  }

  asdf_nim_cleanup_temp() {
    if [ -d "$ASDF_NIM_TEMP" ]; then
      if [ "$ASDF_NIM_REMOVE_TEMP" = "yes" ]; then
        out "# Cleaning up temp dir…"
        rm -rf "$ASDF_NIM_TEMP"
      else
        out "# ASDF_NIM_REMOVE_TEMP=${ASDF_NIM_REMOVE_TEMP}, keeping temp dir ${ASDF_NIM_TEMP}"
      fi
    fi
  }

  case "$ASDF_NIM_ACTION" in
    download)
      # install gets called by asdf even after a failed download, so don't do
      # any cleanup here... *unless* ASDF_NIM_SIGNAL is set, in which case
      # install will not be called and ASDF_DOWNLOAD_PATH should be deleted
      # regardless of --keep-download/always_keep_download.
      case "${ASDF_NIM_SIGNAL:-}" in
        SIG*)
          # cleanup everything
          out
          asdf_nim_cleanup_asdf_install_path
          asdf_nim_cleanup_asdf_download_path force
          asdf_nim_cleanup_temp
          out
          ;;
        *) ;;
      esac
      ;;
    install)
      # actually do cleanup here
      case "$ASDF_NIM_EXIT_STATUS" in
        0)
          # successful install, only clean up temp dir, make download path
          # removable.
          out
          asdf_nim_cleanup_asdf_download_path
          asdf_nim_cleanup_temp
          out
          ;;
        *)
          # failure, dump log
          out
          out "# 😱 Exited with status ${ASDF_NIM_EXIT_STATUS}:"
          out
          cat "$(asdf_nim_log download)" >&$ASDF_NIM_STDOUT 2>&$ASDF_NIM_STDERR
          cat "$(asdf_nim_log install)" >&$ASDF_NIM_STDOUT 2>&$ASDF_NIM_STDERR
          # cleanup everything
          out
          asdf_nim_cleanup_asdf_install_path
          asdf_nim_cleanup_asdf_download_path
          asdf_nim_cleanup_temp
          out
          ;;
      esac
      ;;
  esac
}

# Log file path. Most command output gets redirected here.
asdf_nim_log() {
  local path="${ASDF_NIM_TEMP}/${1:-$ASDF_NIM_ACTION}.log"
  touch "$path"
  echo "$path"
}

section_start() {
  outf "\n%s\n" "# $1"
}

step_start() {
  outf "# %s%s" "↳ $1" "… "
}

step_end() {
  outf "%s\n" "$1"
}

# Sort semantic version numbers.
asdf_nim_sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

# List all available Nim versions (tagged releases at github.com/nim-lang/Nim).
asdf_nim_list_all_versions() {
  git ls-remote --tags --refs "$SOURCE_REPO" |
    grep -o 'refs/tags/.*' |
    cut -d/ -f3- |
    sed 's/^v//' |
    asdf_nim_sort_versions
}

asdf_nim_normalize_os() {
  local os
  os="$(echo "${ASDF_NIM_MOCK_OS_NAME:-$(uname)}" | tr '[:upper:]' '[:lower:]')"
  case "$os" in
    darwin) echo macos ;;
    mingw*) echo windows ;;
    *) echo "$os" ;;
  esac
}

asdf_nim_exe_ext() {
  case "$(asdf_nim_normalize_os)" in
    windows) echo ".exe" ;;
  esac
}

# Detect the platform's architecture, normalize it to one of the following, and
# echo it:
# - x86_64
# - i686
# - armv5
# - armv6
# - armv7
# - aaarch64 (on Linux)
# - arm64 (on macOS)
# - powerpc64le
asdf_nim_normalize_arch() {
  local arch
  arch="${ASDF_NIM_MOCK_MACHINE_NAME:-$(uname -m)}"
  case "$arch" in
    x86_64 | x64 | amd64)
      # Detect 386 container on amd64 using __amd64 definition
      IS_AMD64="$(echo "${ASDF_NIM_MOCK_GCC_DEFINES:-$(gcc -dM -E - </dev/null)}" | grep "#define __amd64 " | sed 's/#define __amd64 //')"
      [ "$IS_AMD64" = "1" ] && echo x86_64 || echo i686
      ;;
    *86* | x32) echo i686 ;;
    *aarch64* | *arm64* | armv8b | armv8l)
      case "$(asdf_nim_normalize_os)" in
        macos | windows) echo arm64 ;;
        *) echo aarch64 ;;
      esac
      ;;
    arm*)
      # Detect arm32 version using __ARM_ARCH definition
      ARM_ARCH="$(echo "${ASDF_NIM_MOCK_GCC_DEFINES:-$(gcc -dM -E - </dev/null)}" | grep "#define __ARM_ARCH " | sed 's/#define __ARM_ARCH //')"
      [ -n "$ARM_ARCH" ] && echo "armv$ARM_ARCH" || echo "$arch"
      ;;
    ppc64le | powerpc64le | ppc64el | powerpc64el) echo powerpc64le ;;
    *) echo "$arch" ;;
  esac
}

asdf_nim_pkg_mgr() {
  echo "${ASDF_NIM_MOCK_PKG_MGR:-$(
    (which brew >/dev/null 2>&1 && echo "brew") ||
      (which apt-get >/dev/null 2>&1 && echo "apt-get") ||
      (which apk >/dev/null 2>&1 && echo "apk") ||
      (which pacman >/dev/null 2>&1 && echo "pacman") ||
      (which dnf >/dev/null 2>&1 && echo "dnf") ||
      (which choco >/dev/null 2>&1 && echo "choco") ||
      echo ""
  )}"
}

# List dependencies of this plugin, as package names for use with the system
# package manager.
asdf_nim_list_deps() {
  echo hub
  case "$(asdf_nim_pkg_mgr)" in
    apt-get)
      echo xz-utils
      echo build-essential
      ;;
    apk)
      echo xz
      echo build-base
      ;;
    brew) echo xz ;;
    *)
      case "$(asdf_nim_normalize_os)" in
        windows)
          echo unzip
          echo mingw
          ;;
        *)
          echo xz
          echo gcc
          ;;
      esac
      ;;
  esac
}

# Generate the command to install dependencies via the system package manager.
asdf_nim_install_deps_cmds() {
  local deps="$(asdf_nim_list_deps | xargs)"
  case "$(asdf_nim_pkg_mgr)" in
    apt-get) echo "apt-get update -q -y && apt-get -qq install -y $deps" ;;
    apk)
      printf "%s" "apk add --update $(echo $deps | sed 's/hub //') && "
      printf "%s" "apk add --update --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing hub"
      echo
      ;;
    brew) echo "brew install $deps" ;;
    pacman) echo "pacman -Syu --noconfirm $deps" ;;
    dnf) echo "dnf install -y $deps" ;;
    choco) echo "choco install --yes $deps" ;;
    *) echo "" ;;
  esac
}

# Install missing dependencies using the system package manager.
# Note - this is interactive, so in CI use `yes | cmd-that-calls-asdf_nim_install_deps`.
asdf_nim_install_deps() {
  local deps="$(asdf_nim_list_deps | xargs)"
  local input=""
  echo
  echo "[asdf-nim:install-deps] additional packages are required: ${deps}"
  echo
  if [ "${ASDF_NIM_INSTALL_DEPS_ACCEPT:-no}" = "no" ]; then
    read -r -p "[asdf-nim:install-deps] Install them now? [Y/n] " input
  else
    echo "[asdf-nim:install-deps] --yes passed, installing…"
    input="yes"
  fi
  echo

  case "$input" in
    [yY][eE][sS] | [yY] | "")
      local cmds="$(asdf_nim_install_deps_cmds)"
      if [ -z "$cmds" ]; then
        echo
        echo "[asdf-nim:install-deps] no package managers recognized, install the packages manually."
        echo
        return 1
      else
        eval "$cmds"
        echo
        echo "[asdf-nim:install-deps] installed: ${deps}"
        echo
      fi
      ;;
    *)
      echo
      echo "[asdf-nim:install-deps] plugin will not function without: ${deps}"
      echo
      return 1
      ;;
  esac
  echo
}

# Detect if the standard C library on the system is musl or not.
# Echoes "yes" or "no"
asdf_nim_is_musl() {
  echo "${ASDF_NIM_MOCK_IS_MUSL:-$(
    local libc_path=$(ldconfig -p 2>/dev/null | grep -F "libc.so." | tr ' ' '\n' | grep -F "/" | head -n 1 || ls /lib/libc.so.* 2>/dev/null || true)
    ([ -n "$(${libc_path} | grep musl)" ] && echo yes) || echo no
  )}"
}

# Echo the suffix for a gcc toolchain triple, e.g. `musleabihf` for a
# `arm-unknown-linux-musleabihf` toolchain.
asdf_nim_lib_suffix() {
  case "$(asdf_nim_normalize_os)" in
    linux)
      local libc
      case "$(asdf_nim_is_musl)" in
        yes) libc="musl" ;;
        no) libc="gnu" ;;
      esac
      case "$(asdf_nim_normalize_arch)" in
        armv5) echo "${libc}eabi" ;;
        armv6) echo "${libc}eabihf" ;;
        armv7) echo "${libc}eabihf" ;;
        *) echo $libc ;;
      esac
      ;;
    macos)
      case "${ASDF_NIM_MOCK_MAC_OS_VERSION:-"$(defaults read loginwindow SystemVersionStampAsString)"}" in
        10.15.* | 11.* | 12.* | 13.*) echo "catalina" ;; # For now, everything >=10.15 gets catalina builds
        *) echo "unknown" ;;
      esac
      ;;
    *) echo "" ;;
  esac
}

# Echo the official binary archive URL (from nim-lang.org) for the current
# architecture.
asdf_nim_official_archive_url() {
  case "$(asdf_nim_normalize_os)" in
    linux)
      case "$(asdf_nim_normalize_arch)" in
        x86_64) echo "$LINUX_X64_URL" | sed "s/{version}/${ASDF_INSTALL_VERSION}/" ;;
        i686) echo "$LINUX_X32_URL" | sed "s/{version}/${ASDF_INSTALL_VERSION}/" ;;
      esac
      ;;
    windows)
      case "$(asdf_nim_normalize_arch)" in
        x86_64) echo "$WINDOWS_X64_URL" | sed "s/{version}/${ASDF_INSTALL_VERSION}/" ;;
        i686) echo "$WINDOWS_X32_URL" | sed "s/{version}/${ASDF_INSTALL_VERSION}/" ;;
      esac
      ;;
  esac
}

asdf_nim_github_token() {
  # hub uses GITHUB_TOKEN for auth, asdf uses GITHUB_API_TOKEN
  echo "${GITHUB_TOKEN:-${GITHUB_API_TOKEN:-}}"
}

# Verify that the user has provided some means to authenticate with github
asdf_nim_assert_github_auth() {
  if [ -n "${GITHUB_USER:-}" ] && [ -n "${GITHUB_PASSWORD:-}" ]; then
    return 0
  elif [ -n "$(asdf_nim_github_token)" ]; then
    return 0
  elif [ -f "${XDG_CONFIG_HOME:-"${HOME}/.config"}/hub" ]; then
    return 0
  fi
  return 1
}

asdf_nim_unofficial_archive_name() {
  echo "nim-${ASDF_INSTALL_VERSION}--$(asdf_nim_normalize_arch)-$(asdf_nim_normalize_os)-$(asdf_nim_lib_suffix).tar.xz"
}

asdf_nim_unofficial_archive_url_via_hub() {
  local nim_builds_repo="${ASDF_NIM_TEMP}/nim-builds"
  mkdir -p "$nim_builds_repo"
  cd "$nim_builds_repo"
  git init . 1>/dev/null 2>&1
  git remote add origin "$NIM_BUILDS_REPO" 1>/dev/null 2>&1

  local releases=($(yes | GITHUB_TOKEN=$(asdf_nim_github_token) hub release -L 100 || echo ""))
  local archive="$(asdf_nim_unofficial_archive_name)"
  local url=""
  # Search through releases looking for a matching binary
  for release in "${releases[@]}"; do
    case "$release" in
      nim-${ASDF_INSTALL_VERSION}--*)
        url="$(yes | GITHUB_TOKEN=$(asdf_nim_github_token) hub release show "$release" --show-downloads | grep -F "$archive" || echo "")"
        ;;
    esac
    if [ -n "$url" ]; then
      break
    fi
  done
  cd - 1>/dev/null 2>&1
  echo "$url"
}

asdf_nim_unofficial_archive_url_via_cache() {
  local archive="$(asdf_nim_unofficial_archive_name)"
  echo "$(cat "${ASDF_DATA_DIR}/plugins/nim/share/unofficial-binaries.txt" 2>/dev/null | grep -F "$archive" | head -n 1 || echo "")"
}

# Echo the unofficial binary archive URL (from github.com/elijahr/nim-builds)
# for the current architecture.
asdf_nim_unofficial_archive_url() {
  local url="$(asdf_nim_unofficial_archive_url_via_cache)"
  if [ -z "$url" ]; then
    asdf_nim_assert_github_auth && url="$(asdf_nim_unofficial_archive_url_via_hub)" || true
  fi
  echo "$url"
}

# Echo the source archive URL (from nim-lang.org).
asdf_nim_source_url() {
  echo "$SOURCE_URL" | sed "s/{version}/${ASDF_INSTALL_VERSION}/"
}

asdf_nim_needs_download() {
  (
    # No download path
    [ ! -d "$ASDF_DOWNLOAD_PATH" ]
  ) && (
    echo "yes"
  ) || (
    echo "no"
  )
}

asdf_nim_search_nim_builds() {
  step_start "Searching for a binary build"
  local url="$(asdf_nim_unofficial_archive_url)"
  if [ -z "$url" ]; then
    step_end "not found"
  else
    step_end "found"
  fi
  echo "$url"
}

asdf_nim_download_urls() {
  case "$ASDF_NIM_REQUIRE_BUILD_FROM_SOURCE" in
    yes) asdf_nim_source_url ;;
    *)
      case "$(asdf_nim_normalize_os)" in
        linux)
          case "$(asdf_nim_is_musl)" in
            # Distros using musl can't use official Nim binaries
            yes)
              asdf_nim_search_nim_builds
              asdf_nim_source_url
              ;;
            no)
              case "$(asdf_nim_normalize_arch)" in
                x86_64 | i686)
                  # Linux with glibc has official x86_64 & x86 binaries
                  asdf_nim_official_archive_url
                  asdf_nim_source_url
                  ;;
                *)
                  asdf_nim_search_nim_builds
                  asdf_nim_source_url
                  ;;
              esac
              ;;
          esac
          ;;
        macos)
          asdf_nim_search_nim_builds
          asdf_nim_source_url
          ;;
        windows)
          case "$(asdf_nim_normalize_arch)" in
            x86_64 | i686)
              # Windows has official x86_64 & x86 binaries
              asdf_nim_official_archive_url
              asdf_nim_source_url
              ;;
            *) asdf_nim_source_url ;;
          esac
          ;;
        *) asdf_nim_source_url ;;
      esac
      ;;
  esac
}

# Detect which method to install Nim with (build from source, official binary,
# or unofficial binary), download the code to ASDF_NIM_DOWNLOAD_PATH, prepare it for
# use by the build or install functions, then move it to ASDF_DOWNLOAD_PATH.
asdf_nim_download() {
  {
    echo "$(date +%s)" >"${ASDF_NIM_TEMP}/download.start"

    if [ "$ASDF_NIM_DEBUG" = "yes" ]; then
      set -x
    fi
    section_start "Downloading Nim to ${ASDF_NIM_DOWNLOAD_PATH}"

    rm -rf "$ASDF_NIM_DOWNLOAD_PATH"
    mkdir -p "$ASDF_NIM_DOWNLOAD_PATH"

    case "$ASDF_INSTALL_TYPE" in
      ref)
        step_start "Cloning repo"
        cd "$ASDF_NIM_DOWNLOAD_PATH"
        git init
        git remote add origin "$SOURCE_REPO"
        git fetch origin "$ASDF_INSTALL_VERSION" --depth 1
        git reset --hard FETCH_HEAD
        chmod -R 700 . # For asdf cleanup
        cd -
        step_end "done"
        ;;
      version)
        local urls=($(asdf_nim_download_urls))

        local url=""
        local archive_path=""
        for i in "${!urls[@]}"; do
          url="${urls[$i]}"
          step_start "Downloading ${url}"
          archive_path="$(asdf_nim_fetch "$url")"
          if [ -n "$archive_path" ]; then
            step_end "done"
            break
          else
            if [ "$(($i + 1))" -ge "${#urls[@]}" ]; then
              step_end "failed, no more URLs to try"
              return 1
            else
              step_end "failed, trying another URL"
            fi
          fi
        done
        local archive_name="$(basename $url)"
        local archive_ext="${archive_name##*.}"
        step_start "Unpacking"
        case "$archive_ext" in
          xz) tar -xJf "${ASDF_NIM_TEMP}/${archive_name}" -C "$ASDF_NIM_DOWNLOAD_PATH" --strip-components=1 ;;
          *)
            unzip -q "${ASDF_NIM_TEMP}/${archive_name}" -d "$ASDF_NIM_DOWNLOAD_PATH"
            mv -v "$ASDF_NIM_DOWNLOAD_PATH/nim-${ASDF_INSTALL_VERSION}/"* "$ASDF_NIM_DOWNLOAD_PATH"
            rm -vr "$ASDF_NIM_DOWNLOAD_PATH/nim-${ASDF_INSTALL_VERSION}"
            ;;
        esac
        step_end "done"
        ;;
    esac

    step_start "Moving download to ${ASDF_DOWNLOAD_PATH}"
    rm -rf "$ASDF_DOWNLOAD_PATH"
    mkdir -p "$(dirname "$ASDF_DOWNLOAD_PATH")"
    mv -v "$ASDF_NIM_DOWNLOAD_PATH" "$ASDF_DOWNLOAD_PATH"
    step_end "done"

    if [ "$ASDF_NIM_DEBUG" = "yes" ]; then
      set +x
    fi
  } 1>>"$(asdf_nim_log)" 2>>"$(asdf_nim_log)"
}

asdf_nim_fetch() {
  local url="$1"
  declare -a curl_args
  curl_args=("-fsSL" "--connect-timeout" "10")

  # Use a github personal access token to avoid API rate limiting
  if [ -n "$(asdf_nim_github_token)" ]; then
    case "$url" in
      *github.com*)
        curl_args+=("-H" "Authorization: token $(asdf_nim_github_token)")
        ;;
    esac
  fi

  # Debian ARMv7 at least seem to have out of date ca certs, so use a newer
  # one from Mozilla.
  case "$(asdf_nim_normalize_arch)" in
    armv*)
      curl_args+=("--cacert" "${ASDF_DATA_DIR}/plugins/nim/share/cacert.pem")
      ;;
  esac
  local archive_name="$(basename $url)"
  local archive_path="${ASDF_NIM_TEMP}/${archive_name}"

  curl_args+=("$url" "-o" "$archive_path")

  eval curl $(printf ' "%s" ' "${curl_args[@]}") && echo "$archive_path" || echo ""
}

asdf_nim_needs_build() {
  (
    [ -f "${ASDF_DOWNLOAD_PATH}/bin/nim$(asdf_nim_exe_ext)" ] &&
      [ -f "${ASDF_DOWNLOAD_PATH}/bin/nimgrep$(asdf_nim_exe_ext)" ] &&
      [ -f "${ASDF_DOWNLOAD_PATH}/bin/nimble$(asdf_nim_exe_ext)" ] &&
      (
        [ -f "${ASDF_DOWNLOAD_PATH}/install.sh" ] ||
          [ "$(asdf_nim_normalize_os)" = "windows" ]
      )
  ) && ( 
    (
      [ "$ASDF_NIM_REQUIRE_BUILD_FROM_SOURCE" = "yes" ]
    ) && (
      echo "yes"
    ) || (
      echo "no"
    )
  ) || (
    echo "yes"
  )
}

asdf_nim_bootstrap_nim() {
  cd "$ASDF_DOWNLOAD_PATH"

  local nim="./bin/nim$(asdf_nim_exe_ext)"
  if [ ! -f "$nim" ]; then
    if [ -f "build.sh" ]; then
      # source directory has build.sh to build koch, nim, and tools.
      step_start "Building with build.sh"
      sh build.sh
      step_end "done"
    elif [ -f "build_all.sh" ]; then
      # source directory has build_all.sh to build koch, nim, and tools.
      step_start "Building with build_all.sh"
      sh build_all.sh
      step_end "done"
    fi
  fi

  [ -f "$nim" ] # A nim executable must exist at this point to proceed
  [ -f "./koch" ] || asdf_nim_build_koch "$nim"
  [ -f "./bin/nim$(asdf_nim_exe_ext)" ] || asdf_nim_build_nim
  cd -
}

asdf_nim_build_koch() {
  local nim="$1"
  step_start "Building koch"
  cd "$ASDF_DOWNLOAD_PATH"
  eval "$nim" c --skipParentCfg:on $(printf ' %q ' "${NIM_ARGS[@]}") koch
  cd -
  step_end "done"
}

asdf_nim_build_nim() {
  step_start "Building nim"
  cd "$ASDF_DOWNLOAD_PATH"
  eval ./koch boot $(printf ' %q ' "${NIM_ARGS[@]}")
  cd -
  step_end "done"
}

asdf_nim_build_tools() {
  step_start "Building tools"
  cd "$ASDF_DOWNLOAD_PATH"
  eval ./koch tools $(printf ' %q ' "${NIM_ARGS[@]}")
  cd -
  step_end "done"
}

asdf_nim_build_nimble() {
  step_start "Building nimble"
  cd "$ASDF_DOWNLOAD_PATH"
  eval ./koch nimble $(printf ' %q ' "${NIM_ARGS[@]}")
  cd -
  step_end "done"
}

asdf_nim_generate_install_sh() {
  step_start "Building niminst"
  cd "$ASDF_DOWNLOAD_PATH"
  "./bin/nim$(asdf_nim_exe_ext)" c $(printf ' %q ' "${NIM_ARGS[@]}") tools/niminst/niminst
  step_end "done"
  step_start "Generating install.sh"
  eval ./tools/niminst/niminst scripts ./compiler/installer.ini
  cd -
  step_end "done"
}

# Build Nim binaries in ASDF_NIM_DOWNLOAD_PATH.
asdf_nim_build() {
  section_start "Building Nim in $ASDF_NIM_DOWNLOAD_PATH"
  cd "$ASDF_DOWNLOAD_PATH"
  [ -f "./bin/nim$(asdf_nim_exe_ext)" ] || asdf_nim_bootstrap_nim
  [ -f "./bin/nimgrep$(asdf_nim_exe_ext)" ] || asdf_nim_build_tools
  [ -f "./bin/nimble$(asdf_nim_exe_ext)" ] || asdf_nim_build_nimble
  if [ "$(asdf_nim_normalize_os)" != "windows" ]; then
    [ -f "./install.sh" ] || asdf_nim_generate_install_sh
  fi
  cd -
}

asdf_nim_time() {
  local start="$(cat "${ASDF_NIM_TEMP}/download.start" 2>/dev/null || true)"
  if [ -n "$start" ]; then
    local now="$(date +%s)"
    local secs="$(($now - $start))"
    local mins="0"
    if [[ "$secs" -ge 60 ]]; then
      local time_mins="$(echo "scale=2; ${secs}/60" | bc)"
      mins="$(echo ${time_mins} | cut -d'.' -f1)"
      secs="0.$(echo ${time_mins} | cut -d'.' -f2)"
      secs="$(echo ${secs}*60 | bc | awk '{print int($1+0.5)}')"
    fi
    echo " in ${mins}m${secs}s"
  fi
}
