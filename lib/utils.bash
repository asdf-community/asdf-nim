#!/usr/bin/env bash

set -euo pipefail
shopt -s dotglob

SOURCE_REPO="https://github.com/nim-lang/Nim.git"
SOURCE_URL="https://nim-lang.org/download/nim-{version}.tar.xz"
LINUX_X64_URL="https://nim-lang.org/download/nim-{version}-linux_x64.tar.xz"
LINUX_X32_URL="https://nim-lang.org/download/nim-{version}-linux_x32.tar.xz"
NIM_BUILDS_REPO="https://github.com/elijahr/nim-builds.git"

# hub uses GITHUB_TOKEN for auth, asdf uses GITHUB_API_TOKEN
export GITHUB_TOKEN="${GITHUB_TOKEN:-${GITHUB_API_TOKEN:-}}"

# Create a temporary directory and echo its path (cross-platform).
mktmpdir() {
  mktemp -d 2>/dev/null || mktemp -d -t 'asdf-nim'
}

# Path to a temporary directory used by the download/build/install functions.
# This path is set in the init_temp function.
TEMP=""

# Build log file path. Most command output gets redirected here.
# This path is set in the init_temp function.
LOG=""

# Path where the requested Nim version's source or binaries are downloaded.
# This will either be the value of ASDF_DOWNLOAD_PATH, or a temporary directory
# inside of TEMP. To retain downloads, pass --keep-download to asdf.
DOWNLOAD_PATH=""

# Dump the build log.
dump_log() {
  if [ "$LOG" != "" ]; then
    echo -e
    echo -e "Build log:"
    echo -e
    cat 1>&2 "$LOG"
  fi
}

# Print a fail icon, dump the build log, and exit the script with status 1.
dump_log_and_fail() {
  step_fail
  dump_log
  fail
}

# Run a command silently, redirecting its output to the build log.
# If the command fails, dump the build log and exit the script with status 1.
log() {
  echo "+ $@" >>"$LOG"
  eval "$@" >>"$LOG" 2>&1 || dump_log_and_fail
}

# On user cancel, print a fail icon and dump the build log.
trap dump_log_and_fail INT

# Create the temp directories used by the download/build/install functions.
init_temp() {
  if [ "$TEMP" = "" ]; then
    cleanup_temp

    TEMP="$(mktmpdir)"
    LOG="${TEMP}/asdf-nim.log"
    DOWNLOAD_PATH="${ASDF_DOWNLOAD_PATH:-${TEMP}/download}"

    mkdir -p "${TEMP}/install"
    mkdir -p "$DOWNLOAD_PATH"
    touch "$LOG"
  fi
}

# Cleanup the temp directories used by the download/build/install functions.
cleanup_temp() {
  if [ -d "$TEMP" ]; then
    rm -rf "$TEMP"
    TEMP=""
    DOWNLOAD_PATH=""
    LOG=""
  fi

  # Allow asdf to cleanup the various .git directories in ASDF_DOWNLOAD_PATH
  if [ -d "$ASDF_DOWNLOAD_PATH" ]; then
    chmod -R 766 "$ASDF_DOWNLOAD_PATH"
  fi
}

# On script exit, remove temp directory.
trap cleanup_temp EXIT

# Print a message indicating that an install step is in progress.
step_start() {
  local message="$1"
  printf "%s%s" "- $message" "… "
  echo ">>> STEP: $message >>>" >>"$LOG"
  echo >>"$LOG"
}

# Print a success icon and move the cursor to the next line.
step_success() {
  printf "✅"
  echo
}

# Print a skip icon and move the cursor to the next line.
step_skip() {
  printf "❎"
  echo
}

# Print a fail icon and move the cursor to the next line.
step_fail() {
  printf "❌"
  echo
}

# Print a message and exit with status 1.
fail() {
  echo -e
  echo -e "[asdf-nim] ${1:-Failed, see log above}"
  echo -e
  exit 1
}

# Sort semantic version numbers.
sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

# List all available Nim versions (tagged releases at github.com/nim-lang/Nim).
list_all_versions() {
  git ls-remote --tags --refs "$SOURCE_REPO" |
    grep -o 'refs/tags/.*' | cut -d/ -f3- |
    sed 's/^v//'
}

normalize_os() {
  local os
  os="$(uname)"
  case "$os" in
    Darwin) echo macos ;;
    *) echo "$os" | tr '[:upper:]' '[:lower:]' ;;
  esac
}

OS="$(normalize_os)"

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
normalize_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64 | x64 | amd64)
      # Detect 386 container on amd64 using __amd64 definition
      IS_AMD64=$(gcc -dM -E - </dev/null | grep "#define __amd64 " | sed 's/#define __amd64 //')
      if [ "$IS_AMD64" = "1" ]; then
        echo x86_64
      else
        echo i686
      fi
      ;;
    *86*)
      echo i686
      ;;
    *aarch64* | *arm64* | armv8b | armv8l)
      case "$OS" in
        macos) echo arm64 ;;
        *) echo aarch64 ;;
      esac
      ;;
    arm*)
      # Detect arm32 version using __ARM_ARCH definition
      ARM_ARCH=$(gcc -dM -E - </dev/null | grep "#define __ARM_ARCH " | sed 's/#define __ARM_ARCH //')
      echo "armv$ARM_ARCH"
      ;;
    ppc64le | powerpc64le | ppc64el | powerpc64el)
      echo powerpc64le
      ;;
    *) echo "$arch" ;;
  esac
}

ARCH="$(normalize_arch)"

# List dependencies of this plugin, as package names for use with the system
# package manager.
list_deps() {
  local distro

  echo hub

  if [ "$(which apt || true)" != "" ]; then
    # debian/ubuntu
    echo xz-utils
  else
    echo xz
  fi
}

# Generate the command to install dependencies via the system package manager.
install_cmd() {
  (which brew >/dev/null 2>&1 && echo "brew install") ||
    (which apt-get >/dev/null 2>&1 && echo "apt-get update -q -y && apt-get -qq install -y") ||
    (which apk >/dev/null 2>&1 && echo "apk add --update") ||
    (which pacman >/dev/null 2>&1 && echo "pacman -Syu --noconfirm") ||
    (which dnf >/dev/null 2>&1 && echo "dnf install -y") ||
    echo ""
}

# List dependencies which are not installed.
list_deps_missing() {
  local deps
  declare -a deps=($(list_deps))
  for dep in ${deps[@]}; do
    case "$dep" in
      xz-utils)
        which xz >/dev/null 2>&1 || echo "$dep"
        ;;
      *)
        which "$dep" >/dev/null 2>&1 || echo "$dep"
        ;;
    esac
  done
}

# Install missing dependencies using the system package manager.
# Note - this is interactive, so in CI use `yes | cmd-that-calls-install_deps`.
install_deps() {
  local missing="$(list_deps_missing | xargs)"

  if [ "$missing" != "" ]; then
    local input=""
    echo
    echo "[asdf-nim:install-deps] additional packages are required: ${missing}"
    echo
    read -r -p "Install them now? [Y/n] " input

    case "$input" in
      [yY][eE][sS] | [yY] | "")
        local cmd="$(install_cmd)"
        if [ "$cmd" = "" ]; then
          echo
          echo "[asdf-nim:install-deps] could not find a package manager"
          echo
          exit 1
        else
          eval "${cmd} ${missing}"
          echo
          echo "[asdf-nim:install-deps] installed: ${missing}"
          echo
        fi
        ;;
      *)
        echo
        echo "[asdf-nim:install-deps] plugin will not function without ${missing}"
        echo
        exit 1
        ;;
    esac
    echo
  else
    echo
    echo "[asdf-nim:install-deps] packages already installed: $(list_deps)"
    echo
  fi
}

# Detect if the standard C library on the system is musl or not.
# Echoes "yes" or "no"
is_musl() {
  local libc_path=$(ldconfig -p | grep libc.so. | tr ' ' '\n' | grep / || ls /lib/libc.so.*)
  ([ "$(${libc_path} | grep musl)" != "" ] && echo yes) || echo no
}

# Echo the suffix for a gcc toolchain triple, e.g. `musleabihf` for a
# `arm-unknown-linux-musleabihf` toolchain.
lib_suffix() {
  case "$OS" in
    linux)
      local libc
      case "$(is_musl)" in
        yes) libc="musl" ;;
        no) libc="gnu" ;;
      esac
      case "$(normalize_arch)" in
        armv5) echo "${libc}eabi" ;;
        armv6) echo "${libc}eabihf" ;;
        armv7) echo "${libc}eabihf" ;;
        *) echo $libc ;;
      esac
      ;;
    macos)
      case "$(defaults read loginwindow SystemVersionStampAsString)" in
        10.15.*) echo "catalina" ;;
        11.*) echo "bigsur" ;;
        *) echo "unknown" ;;
      esac
      ;;
    *) echo "" ;;
  esac
}

# Echo the official binary tarball URL (from nim-lang.org) for the current
# architecture.
official_tarball_url() {
  case "$ARCH" in
    x86_64) echo "$LINUX_X64_URL" | sed "s/{version}/${ASDF_INSTALL_VERSION}/" ;;
    i686) echo "$LINUX_X32_URL" | sed "s/{version}/${ASDF_INSTALL_VERSION}/" ;;
    *) echo "" ;;
  esac
}

# Verify that the user has provided some means to authenticate with github
assert_github_auth() {
  if [ "${GITHUB_USER:-}" != "" ] && [ "${GITHUB_PASSWORD:-}" != "" ]; then
    return 0
  elif [ "$GITHUB_TOKEN" != "" ]; then
    return 0
  elif [ -f "${HOME}/.config/hub" ]; then
    return 0
  fi
  return 1
}

unofficial_tarball_url_via_hub() {
  local nim_builds_repo="${TEMP}/nim-builds"
  log mkdir -p "$nim_builds_repo"
  log cd "$nim_builds_repo"
  log git init .
  log git remote add origin "$NIM_BUILDS_REPO"

  local releases=($(yes | hub release -L 100 || echo ""))
  local tarball="nim-${ASDF_INSTALL_VERSION}--${ARCH}-${OS}-$(lib_suffix).tar.xz"
  local url=""
  # Search through releases looking for a matching binary
  for release in "${releases[@]}"; do
    case "$release" in
      nim-${ASDF_INSTALL_VERSION}--*)
        url="$(yes | hub release show "$release" --show-downloads | grep -F "$tarball" || echo "")"
        ;;
    esac
    if [ "$url" != "" ]; then
      break
    fi
  done
  log cd -
  echo "$url"
}

unofficial_tarball_url_via_cache() {
  local tarball="nim-${ASDF_INSTALL_VERSION}--${ARCH}-${OS}-$(lib_suffix).tar.xz"
  echo "$(cat "${ASDF_DIR}/plugins/nim/share/unofficial-binaries.txt" 2>/dev/null | grep -F "$tarball" || echo "")"
}

# Echo the unofficial binary tarball URL (from github.com/elijahr/nim-builds)
# for the current architecture.
unofficial_tarball_url() {
  local url="$(unofficial_tarball_url_via_cache)"
  if [ "$url" = "" ]; then
    assert_github_auth && url="$(unofficial_tarball_url_via_hub)" || true
  fi
  echo "$url"
}

# Echo the source tarball URL (from nim-lang.org).
source_url() {
  echo "$SOURCE_URL" | sed "s/{version}/${ASDF_INSTALL_VERSION}/"
}

# Detect which method to install Nim with (build from source, official binary,
# or unofficial binary), download the code to DOWNLOAD_PATH, and prepare it for
# use by the build or install functions.
download() {
  init_temp

  DOWNLOAD_PATH="${ASDF_DOWNLOAD_PATH:-${TEMP}/download}"

  echo "+ download" >>"$LOG"

  local url=""
  echo
  echo "# Downloading"

  case "$ASDF_INSTALL_TYPE" in
    ref)
      step_start "Cloning repo"
      log rm -rf "$DOWNLOAD_PATH"
      log mkdir -p "$DOWNLOAD_PATH"
      log cd "$DOWNLOAD_PATH"
      log git init
      log git remote add origin "$SOURCE_REPO"
      log git fetch origin "$ASDF_INSTALL_VERSION" --depth 1
      log git reset --hard FETCH_HEAD
      log cd -
      step_success
      ;;
    version)
      local tarball_source_name=""

      search_nim_builds() {
        step_start "Searching nim-builds releases for binaries"
        url="$(unofficial_tarball_url)"
        tarball_source_name="github.com/elijahr/nim-builds"
        if [ "$url" = "" ]; then
          step_skip
        else
          step_success
        fi
      }

      case "$OS" in
        linux)
          case "$(is_musl)" in
            # Distros using musl can't use official Nim binaries
            yes) search_nim_builds ;;
            no)
              case "$ARCH" in
                x86_64 | i686)
                  # Linux with glibc has official x86_64 & x86 binaries
                  url=$(official_tarball_url)
                  tarball_source_name="nim-lang.org"
                  ;;
                *) search_nim_builds ;;
              esac
              ;;
          esac
          ;;
        macos) search_nim_builds ;;
      esac

      if [ "$url" = "" ]; then
        # Couldn't find a binary, fallback to building from source
        url="$(source_url)"
        tarball_source_name="nim-lang.org"
      fi

      local curl_opts="-fvsSL --connect-timeout 10"
      # Use a github personal access token to avoid API rate limiting
      if [ -n "$GITHUB_TOKEN" ]; then
        case "$url" in
          *github.com*)
            curl_opts="$curl_opts -H 'Authorization: token ${GITHUB_TOKEN}'"
            ;;
        esac
      fi

      # Debian ARMv7 at least seem to have out of date ca certs, so use a newer
      # one from Mozilla.
      case "$ARCH" in
        armv*)
          curl_opts="$curl_opts --cacert '${ASDF_DIR}/plugins/nim/share/cacert.pem'"
          ;;
      esac

      step_start "Downloading from ${tarball_source_name}"
      log curl "$curl_opts" "$url" -o "${TEMP}/$(basename $url)"
      step_success
      step_start "Unpacking $(basename "$url")"
      log tar -xJf "${TEMP}/$(basename $url)" -C "$DOWNLOAD_PATH" --strip-components=1
      step_success
      ;;
  esac
}

# Build Nim binaries in DOWNLOAD_PATH.
build() {
  init_temp
  echo "+ build" >>"$LOG"

  echo
  echo "# Building Nim in ${DOWNLOAD_PATH}"

  log cd "$DOWNLOAD_PATH"
  local nim
  if [ ! -f "bin/nim" ]; then
    step_start "Checking for existing nim to bootstrap with"
    # If possible, bootstrap with an existing nim rather than building csources
    nim="$(
      PATH="$(echo "$PATH" | sed 's/\.asdf\//.no-asdf-shims/')" which nim ||
        find ../../../installs/nim -type f -executable -name nim -print -quit 2>/dev/null ||
        find ../../../installs/nim -type f -perm +111 -name nim -print -quit 2>/dev/null ||
        echo
    )"
    if [ "$nim" != "" ]; then
      log cp "$nim" bin/nim
      step_success
    else
      step_skip
    fi
  fi

  local bootstrap="no"
  if [ -f "build.sh" ]; then
    # Tarball release has build.sh to build koch, nim, and tools.
    step_start "Building with build.sh"
    log sh build.sh
    step_success
    bootstrap="yes"
  else
    if [ -f "bin/nim" ]; then
      bootstrap="yes"
    else
      # Fallback to building csources, etc
      step_start "Building with build_all.sh"
      log sh build_all.sh
      step_success
    fi
  fi

  if [ "$bootstrap" = "yes" ]; then
    # Manually build koch, nim, and tools
    if [ ! -f "koch" ]; then
      step_start "Building koch"
      log bin/nim c --parallelBuild:${ASDF_CONCURRENCY:-0} koch
      step_success
    fi
    step_start "Building nim"
    log ./koch boot --parallelBuild:${ASDF_CONCURRENCY:-0} -d:release
    step_success

    step_start "Building tools"
    log ./koch tools --parallelBuild:${ASDF_CONCURRENCY:-0} -d:release
    step_success
  fi

  if [ ! -f "bin/nimble" ]; then
    # Build nimble too
    step_start "Building nimble"
    log ./koch nimble --parallelBuild:${ASDF_CONCURRENCY:-0} -d:release
    step_success
  fi

  if [ ! -f "install.sh" ]; then
    # Create install.sh
    step_start "Building niminst"
    log bin/nim c --parallelBuild:${ASDF_CONCURRENCY:-0} tools/niminst/niminst
    step_success
    step_start "Generating install.sh"
    log ./tools/niminst/niminst scripts ./compiler/installer.ini
    step_success
  fi
  log cd -
}

# Install Nim using the best available method, either from a binary or building
# from source.
# The installation will be placed in ASDF_INSTALL_PATH when complete.
install() {
  init_temp
  echo "+ install" >>$LOG

  log mkdir -p "$DOWNLOAD_PATH"

  # Download path is empty; download & unpack
  if [ "$(ls -A "$DOWNLOAD_PATH")" = "" ]; then
    download
  fi

  # No binaries; build
  if [ ! -f "${DOWNLOAD_PATH}/bin/nimble" ]; then
    build
  fi

  echo
  echo "# Installing"

  # Install
  log cd "$DOWNLOAD_PATH"

  # Use nim's install.sh to install to the custom path
  step_start "Running install.sh"
  log sh install.sh "${TEMP}/install"
  step_success

  step_start "Copying binaries"
  # Un-nest installed files
  log mv "${TEMP}/install/nim/"* "${TEMP}/install"
  log rm -rf "${TEMP}/install/nim"

  # Copy additional tools
  log cp -R "${DOWNLOAD_PATH}/bin/"* "${TEMP}/install/bin"
  step_success

  step_start "Configuring nimble"
  # Create nimble.ini
  log mkdir -p "${TEMP}/install/userconfig/nimble"
  echo "+ echo \"nimbleDir = r\\\"${ASDF_INSTALL_PATH}/nimble\\\"\" >> \"${TEMP}/install/userconfig/nimble/nimble.ini\"" >>"$LOG"
  # Tell nimble where to put package metadata & packages
  echo "nimbleDir = r\"${ASDF_INSTALL_PATH}/nimble\"" >>"${TEMP}/install/userconfig/nimble/nimble.ini"

  # Finalize installation
  step_start "Moving installation files to ${ASDF_INSTALL_PATH}"
  log mv "${TEMP}/install/"* "${ASDF_INSTALL_PATH}"
  step_success

  log cd -

  cleanup_temp

  echo
  echo "Installed Nim ${ASDF_INSTALL_VERSION}"
  echo
}
