#!/usr/bin/env bash

# shellcheck disable=SC2230

# Constants
SOURCE_REPO="https://github.com/nim-lang/Nim.git"
SOURCE_URL="https://nim-lang.org/download/nim-VERSION.tar.xz"

LINUX_X64_NIGHTLY_URL="https://github.com/nim-lang/nightlies/releases/download/latest-BRANCH/linux_x64.tar.xz"
LINUX_X32_NIGHTLY_URL="https://github.com/nim-lang/nightlies/releases/download/latest-BRANCH/linux_x32.tar.xz"
LINUX_ARM64_NIGHTLY_URL="https://github.com/nim-lang/nightlies/releases/download/latest-BRANCH/linux_arm64.tar.xz"
LINUX_ARMV7L_NIGHTLY_URL="https://github.com/nim-lang/nightlies/releases/download/latest-BRANCH/linux_armv7l.tar.xz"
MACOS_X64_NIGHTLY_URL="https://github.com/nim-lang/nightlies/releases/download/latest-BRANCH/macosx_x64.tar.xz"

LINUX_X64_URL="https://nim-lang.org/download/nim-VERSION-linux_x64.tar.xz"
LINUX_X32_URL="https://nim-lang.org/download/nim-VERSION-linux_x32.tar.xz"

NIM_ARGS=("--parallelBuild:${ASDF_CONCURRENCY:-0}" "-d:release") # Args to pass to koch/nim

normpath() {
  # Remove all /./ sequences.
  local path
  path="${1//\/.\//\/}"
  # Remove dir/.. sequences.
  while [[ $path =~ ([^/][^/]*/\.\./?) ]]; do
    path="${path/${BASH_REMATCH[0]}/}"
  done
  echo "$path" | sed 's/\/$//'
}

# Create the temp directories used by the download/build/install functions.
asdf_nim_init() {
  export ASDF_NIM_ACTION
  ASDF_NIM_ACTION="$1"

  # Configuration options
  export ASDF_NIM_REMOVE_TEMP
  ASDF_NIM_REMOVE_TEMP="${ASDF_NIM_REMOVE_TEMP:-yes}" # If no, asdf-nim's temporary directory won't be deleted on exit
  export ASDF_NIM_DEBUG
  ASDF_NIM_DEBUG="${ASDF_NIM_DEBUG:-no}" # If yes, extra information will be logged to the console and every command executed will be logged to the logfile.
  export ASDF_NIM_STDOUT
  ASDF_NIM_STDOUT="${ASDF_NIM_STDOUT:-1}" # The file descriptor where the script's standard output should be directed.
  export ASDF_NIM_STDERR
  ASDF_NIM_STDERR="${ASDF_NIM_STDERR:-2}" # The file descriptor where the script's standard error output should be directed.
  export ASDF_NIM_SILENT
  ASDF_NIM_SILENT="${ASDF_NIM_SILENT:-no}" # If yes, asdf-nim will not echo build steps to stdout.
  # End configuration options

  # Ensure ASDF_DATA_DIR has a value
  if [ -n "${ASDF_INSTALL_PATH-}" ]; then
    export ASDF_DATA_DIR
    ASDF_DATA_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}"
    export ASDF_NIM_TEMP
    ASDF_NIM_TEMP="${ASDF_DATA_DIR}/tmp/nim/${ASDF_INSTALL_VERSION}"
    export ASDF_NIM_DOWNLOAD_PATH
    ASDF_NIM_DOWNLOAD_PATH="${ASDF_NIM_TEMP}/download" # Temporary directory where downloads are placed
    export ASDF_NIM_INSTALL_PATH
    ASDF_NIM_INSTALL_PATH="${ASDF_NIM_TEMP}/install" # Temporary directory where installation is prepared
    mkdir -p "$ASDF_NIM_TEMP"
    rm -f "$(asdf_nim_log)"
  fi

  if [ "$ASDF_NIM_DEBUG" = "yes" ]; then
    out
    out "# Environment:"
    out
    env | grep "^ASDF_" | sort | xargs printf "#  %s\n" 1>&"$ASDF_NIM_STDOUT" 2>&"$ASDF_NIM_STDERR" || true
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
    echo "$@" 1>&"$ASDF_NIM_STDOUT" 2>&"$ASDF_NIM_STDERR"
  fi
}

asdf_nim_on_exit() {
  asdf_nim_cleanup_asdf_install_path() {
    if [ -d "$ASDF_INSTALL_PATH" ]; then
      step_start "rm ${ASDF_INSTALL_PATH//${HOME}/\~} …"
      rm -rf "$ASDF_INSTALL_PATH"
      step_end "✓"
    fi
  }

  asdf_nim_cleanup_asdf_download_path() {
    if [ -d "$ASDF_DOWNLOAD_PATH" ]; then
      if [ "${1-}" = "force" ]; then
        # Force delete
        step_start "rm ${ASDF_DOWNLOAD_PATH//${HOME}/\~}"
        rm -rf "$ASDF_DOWNLOAD_PATH"
        step_end "✓"
      else
        # asdf will delete this folder depending on --keep-download or
        # always_keep_download flag, so respect that by not deleting here;
        # however, asdf uses `rm -r` instead of `rm -rf` which fails to delete
        # protected git objects. So we simply chmod the git objects so they
        # can be deleted if asdf decides to delete.
        step_start "chmod ${ASDF_DOWNLOAD_PATH//${HOME}/\~}"
        chmod -R 700 "$ASDF_DOWNLOAD_PATH"
        step_end "✓"
      fi
    fi
  }

  asdf_nim_cleanup_temp() {
    if [ -d "$ASDF_NIM_TEMP" ]; then
      if [ "$ASDF_NIM_REMOVE_TEMP" = "yes" ]; then
        step_start "rm ${ASDF_NIM_TEMP//${HOME}/\~}"
        rm -rf "$ASDF_NIM_TEMP"
        step_end "✓"
      else
        step_start "ASDF_NIM_REMOVE_TEMP=${ASDF_NIM_REMOVE_TEMP}, keeping temp dir ${ASDF_NIM_TEMP//${HOME}/\~}"
        step_end "✓"
      fi
    fi
  }

  case "$ASDF_NIM_ACTION" in
    download)
      # install gets called by asdf even after a failed download, so don't do
      # any cleanup here... *unless* ASDF_NIM_SIGNAL is set, in which case
      # install will not be called and ASDF_DOWNLOAD_PATH should be deleted
      # regardless of --keep-download/always_keep_download.
      case "${ASDF_NIM_SIGNAL-}" in
        SIG*)
          # cleanup everything
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
          asdf_nim_cleanup_asdf_download_path
          asdf_nim_cleanup_temp
          out
          ;;
        *)
          # failure, dump log
          out
          out "😱 Exited with status ${ASDF_NIM_EXIT_STATUS}:"
          out
          cat "$(asdf_nim_log download)" 1>&"$ASDF_NIM_STDOUT" 2>&"$ASDF_NIM_STDERR"
          cat "$(asdf_nim_log install)" 1>&"$ASDF_NIM_STDOUT" 2>&"$ASDF_NIM_STDERR"
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
  local path
  path="${ASDF_NIM_TEMP}/${1:-$ASDF_NIM_ACTION}.log"
  touch "$path"
  echo "$path"
}

STEP=0

section_start() {
  STEP=0
  if [ "$ASDF_NIM_SILENT" = "no" ]; then
    printf "\n%s\n" "$1" 1>&"$ASDF_NIM_STDOUT" 2>&"$ASDF_NIM_STDERR"
  fi
}

step_start() {
  export STEP=$((STEP + 1))
  if [ "$ASDF_NIM_SILENT" = "no" ]; then
    printf "     %s. %s … " "$STEP" "$1" 1>&"$ASDF_NIM_STDOUT" 2>&"$ASDF_NIM_STDERR"
  fi
}

step_end() {
  if [ "$ASDF_NIM_SILENT" = "no" ]; then
    printf "%s\n" "$1" 1>&"$ASDF_NIM_STDOUT" 2>&"$ASDF_NIM_STDERR"
  fi
}

die() {
  if [ "$ASDF_NIM_SILENT" = "no" ]; then
    printf "\n💥 %s\n\n" "$1" 1>&"$ASDF_NIM_STDERR"
  fi
}

# Sort semantic version numbers.
asdf_nim_sort_versions() {
  awk '{ if ($1 ~ /-/) print; else print $0"_" ; }' | sort -V | sed 's/_$//'
}

# List all stable Nim versions (tagged releases at github.com/nim-lang/Nim).
asdf_nim_list_all_versions() {
  git ls-remote --tags --refs "$SOURCE_REPO" |
    awk -v col=2 '{print $col}' |
    grep '^refs/tags/.*' |
    sed 's/^refs\/tags\///' |
    sed 's/^v//' |
    asdf_nim_sort_versions
}

asdf_nim_normalize_os() {
  local os
  os="$(echo "${ASDF_NIM_MOCK_OS_NAME:-$(uname)}" | tr '[:upper:]' '[:lower:]')"
  case "$os" in
    darwin) echo macos ;;
    mingw*) echo windows ;; # not actually supported by asdf?
    *) echo "$os" ;;
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
  local arch arm_arch arch_version
  arch="${ASDF_NIM_MOCK_MACHINE_NAME:-$(uname -m)}"
  case "$arch" in
    x86_64 | x64 | amd64)
      if [ -n "$(command -v gcc)" ] || [ -n "${ASDF_NIM_MOCK_GCC_DEFINES-}" ]; then
        # Edge case: detect 386 container on amd64 kernel using __amd64 definition
        IS_AMD64="$(echo "${ASDF_NIM_MOCK_GCC_DEFINES:-$(gcc -dM -E - </dev/null)}" | grep "#define __amd64 " | sed 's/#define __amd64 //')"
        if [ "$IS_AMD64" = "1" ]; then
          echo "x86_64"
        else
          echo "i686"
        fi
      else
        # No gcc, so can't detect 386 container on amd64 kernel. x86_64 is most likely case
        echo "x86_64"
      fi
      ;;
    *86* | x32) echo "i686" ;;
    *aarch64* | *arm64* | armv8b | armv8l)
      case "$(asdf_nim_normalize_os)" in
        macos) echo arm64 ;;
        *) echo "aarch64" ;;
      esac
      ;;
    arm*)
      arm_arch=""
      if [ -n "$(command -v gcc)" ] || [ -n "${ASDF_NIM_MOCK_GCC_DEFINES-}" ]; then
        # Detect arm32 version using __ARM_ARCH definition
        arch_version="$(echo "${ASDF_NIM_MOCK_GCC_DEFINES:-$(gcc -dM -E - </dev/null)}" | grep "#define __ARM_ARCH " | sed 's/#define __ARM_ARCH //')"
        if [ -n "$arch_version" ]; then
          arm_arch="armv$arch_version"
        fi
      fi
      if [ -z "$arm_arch" ]; then
        if [ -n "$(command -v dpkg)" ] || [ -n "${ASDF_NIM_MOCK_DPKG_ARCHITECTURE-}" ]; then
          # Detect arm32 version using dpkg
          case "${ASDF_NIM_MOCK_DPKG_ARCHITECTURE:-"$(dpkg --print-architecture)"}" in
            armel) arm_arch="armv5" ;;
            armhf) arm_arch="armv7" ;;
          esac
        fi
      fi
      if [ -z "$arm_arch" ]; then
        if [ "$arch" = "arm" ]; then
          # If couldn't detect, go low
          arm_arch="armv5"
        else
          # Something like armv7l -> armv7
          # shellcheck disable=SC2001
          arm_arch="$(echo "$arch" | sed 's/^\(armv[0-9]\{1,\}\).*$/\1/')"
        fi
      fi
      echo "$arm_arch"
      ;;
    ppc64le | powerpc64le | ppc64el | powerpc64el) echo powerpc64le ;;
    *) echo "$arch" ;;
  esac
}

asdf_nim_pkg_mgr() {
  echo "${ASDF_NIM_MOCK_PKG_MGR:-$(
    (command -v brew >/dev/null 2>&1 && echo "brew") ||
      (command -v apt-get >/dev/null 2>&1 && echo "apt-get") ||
      (command -v apk >/dev/null 2>&1 && echo "apk") ||
      (command -v pacman >/dev/null 2>&1 && echo "pacman") ||
      (command -v dnf >/dev/null 2>&1 && echo "dnf") ||
      echo ""
  )}"
}

# List dependencies of this plugin, as package names for use with the system
# package manager.
asdf_nim_list_deps() {
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
  local deps
  deps="$(asdf_nim_list_deps | xargs)"
  case "$(asdf_nim_pkg_mgr)" in
    apt-get) echo "apt-get update -q -y && apt-get -qq install -y $deps" ;;
    apk) echo "apk add --update $deps" ;;
    brew) echo "brew install $deps" ;;
    pacman) echo "pacman -Syu --noconfirm $deps" ;;
    dnf) echo "dnf install -y $deps" ;;
    *) echo "" ;;
  esac
}

# Install missing dependencies using the system package manager.
# Note - this is interactive, so in CI use `yes | cmd-that-calls-asdf_nim_install_deps`.
asdf_nim_install_deps() {
  local deps
  deps="$(asdf_nim_list_deps | xargs)"
  local input
  input=""
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
      local cmds
      cmds="$(asdf_nim_install_deps_cmds)"
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
  if [ -n "${ASDF_NIM_MOCK_IS_MUSL-}" ]; then
    echo "$ASDF_NIM_MOCK_IS_MUSL"
  else
    if [ -n "$(command -v ldd)" ]; then
      if (ldd --version 2>&1 || true) | grep -qF "musl"; then
        echo "yes"
      else
        echo "no"
      fi
    else
      echo "no"
    fi
  fi
}

# Echo the official binary archive URL (from nim-lang.org) for the current
# architecture.
asdf_nim_official_archive_url() {
  if [ "${ASDF_INSTALL_TYPE}" = "version" ] && [[ ${ASDF_INSTALL_VERSION} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    case "$(asdf_nim_normalize_os)" in
      linux)
        case "$(asdf_nim_is_musl)" in
          no)
            # Official Linux builds are only available for glibc x86_64 and x86
            case "$(asdf_nim_normalize_arch)" in
              x86_64) echo "${LINUX_X64_URL//VERSION/$ASDF_INSTALL_VERSION}" ;;
              i686) echo "${LINUX_X32_URL//VERSION/$ASDF_INSTALL_VERSION}" ;;
            esac
            ;;
        esac
        ;;
    esac
  fi
}

# Echo the nightly url for arch/os
asdf_nim_nightly_url() {
  if [ "${ASDF_INSTALL_TYPE}" != "ref" ]; then
    return 0
  fi
  if [[ $ASDF_INSTALL_VERSION =~ ^version-[0-9]+-[0-9]+$ ]] || [ "$ASDF_INSTALL_VERSION" = "devel" ]; then
    case "$(asdf_nim_normalize_os)" in
      linux)
        case "$(asdf_nim_is_musl)" in
          no)
            # Nightly Linux builds are only available for glibc and a few archs
            case "$(asdf_nim_normalize_arch)" in
              x86_64) echo "${LINUX_X64_NIGHTLY_URL//BRANCH/$ASDF_INSTALL_VERSION}" ;;
              i686) echo "${LINUX_X32_NIGHTLY_URL//BRANCH/$ASDF_INSTALL_VERSION}" ;;
              aarch64) echo "${LINUX_ARM64_NIGHTLY_URL//BRANCH/$ASDF_INSTALL_VERSION}" ;;
              armv7) echo "${LINUX_ARMV7L_NIGHTLY_URL//BRANCH/$ASDF_INSTALL_VERSION}" ;;
            esac
            ;;
        esac
        ;;
      macos)
        case "$(asdf_nim_normalize_arch)" in
          # Nightly macos builds are only available for x86_64
          x86_64) echo "${MACOS_X64_NIGHTLY_URL//BRANCH/$ASDF_INSTALL_VERSION}" ;;
        esac
        ;;
    esac
  fi
}

asdf_nim_github_token() {
  echo "${GITHUB_TOKEN:-${GITHUB_API_TOKEN-}}"
}

# Echo the source archive URL (from nim-lang.org).
asdf_nim_source_url() {
  if [ "${ASDF_INSTALL_TYPE}" = "version" ] && [[ ${ASDF_INSTALL_VERSION} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "${SOURCE_URL//VERSION/$ASDF_INSTALL_VERSION}"
  fi
}

asdf_nim_needs_download() {
  # No download path
  if [ ! -d "$ASDF_DOWNLOAD_PATH" ]; then
    echo "yes"
  else
    echo "no"
  fi
}

asdf_nim_download_urls() {
  # Official binaries
  asdf_nim_official_archive_url
  # Nightly binaries
  asdf_nim_nightly_url
  # Fall back to building from source
  asdf_nim_source_url
}

asdf_nim_download_via_git() {
  step_start "git clone"
  rm -rf "$ASDF_NIM_DOWNLOAD_PATH"
  mkdir -p "$ASDF_NIM_DOWNLOAD_PATH"
  (
    cd "$ASDF_NIM_DOWNLOAD_PATH" || exit
    git init
    git remote add origin "$SOURCE_REPO"
    git fetch origin "$ASDF_INSTALL_VERSION" --depth 1
    git reset --hard FETCH_HEAD
    chmod -R 700 . # For asdf cleanup
  )
  step_end "✓"
}

asdf_nim_download_via_url() {
  local urls url archive_path archive_name archive_ext
  # shellcheck disable=SC2207
  urls=($(asdf_nim_download_urls))
  url=""
  archive_path=""
  if [ "${#urls[@]}" -eq 0 ]; then
    return 1
  fi
  for i in "${!urls[@]}"; do
    url="${urls[$i]}"
    step_start "curl ${url}"
    archive_path="$(asdf_nim_fetch "$url")"
    if [ -n "$archive_path" ]; then
      step_end "✓"
      break
    else
      if [ "$((i + 1))" -ge "${#urls[@]}" ]; then
        step_end "failed, no more URLs to try"
        return 1
      else
        step_end "failed, trying another URL"
      fi
    fi
  done
  archive_name="$(basename "$url")"
  archive_ext="${archive_name##*.}"
  step_start "unzip"

  rm -rf "$ASDF_NIM_DOWNLOAD_PATH"
  mkdir -p "$ASDF_NIM_DOWNLOAD_PATH"

  case "$archive_ext" in
    xz) tar -xJf "${ASDF_NIM_TEMP}/${archive_name}" -C "$ASDF_NIM_DOWNLOAD_PATH" --strip-components=1 ;;
    *)
      unzip -q "${ASDF_NIM_TEMP}/${archive_name}" -d "$ASDF_NIM_DOWNLOAD_PATH"
      mv -v "$ASDF_NIM_DOWNLOAD_PATH/nim-${ASDF_INSTALL_VERSION}/"* "$ASDF_NIM_DOWNLOAD_PATH"
      rm -vr "$ASDF_NIM_DOWNLOAD_PATH/nim-${ASDF_INSTALL_VERSION}"
      ;;
  esac
  step_end "✓"
}

# Detect which method to install Nim with (official binary, nightly binary, or
# build from source), download the code to ASDF_NIM_DOWNLOAD_PATH, prepare it for
# use by the build or install functions, then move it to ASDF_DOWNLOAD_PATH.
asdf_nim_download() {
  section_start "I.   Download (${ASDF_NIM_DOWNLOAD_PATH//${HOME}/\~})"
  {

    if [ -f "${ASDF_DOWNLOAD_PATH}/install.sh" ] || [ -f "${ASDF_DOWNLOAD_PATH}/build.sh" ] || [ -f "${ASDF_DOWNLOAD_PATH}/build_all.sh" ]; then
      step_start "already downloaded"
      step_end "✓"
      return 0
    fi

    date +%s >"${ASDF_NIM_TEMP}/download.start"

    if [ "$ASDF_NIM_DEBUG" = "yes" ]; then
      set -x
    fi

    # ref install type is usually a git commit-ish
    # but if it one of the "version-X-Y" branches,
    # it may have a nightly build for the current arch/os
    # so first try to download via URL
    # but if none is available, fallback to git
    if ! asdf_nim_download_via_url; then
      if [ "${ASDF_INSTALL_TYPE}" = "ref" ]; then
        asdf_nim_download_via_git
      else
        die "No download method available for ${ASDF_INSTALL_TYPE} ${ASDF_INSTALL_VERSION}"
        return 1
      fi
    fi

    step_start "mv to ${ASDF_DOWNLOAD_PATH//${HOME}/\~}"
    rm -rf "$ASDF_DOWNLOAD_PATH"
    mkdir -p "$(dirname "$ASDF_DOWNLOAD_PATH")"
    mv -v "$ASDF_NIM_DOWNLOAD_PATH" "$ASDF_DOWNLOAD_PATH"
    step_end "✓"

    if [ "$ASDF_NIM_DEBUG" = "yes" ]; then
      set +x
    fi
  } 1>>"$(asdf_nim_log)" 2>>"$(asdf_nim_log)"
}

asdf_nim_fetch() {
  local url
  url="$1"
  declare -a curl_args
  curl_args=("-fsSL" "--connect-timeout" "10")

  # Use a github personal access token to avoid API rate limiting
  if [ -n "$(asdf_nim_github_token)" ]; then
    case "$url" in
      'https://github.com/'*)
        curl_args+=("-H" "Authorization: token $(asdf_nim_github_token)")
        ;;
    esac
  fi

  local archive_name
  archive_name="$(basename "$url")"
  local archive_path
  archive_path="${ASDF_NIM_TEMP}/${archive_name}"

  curl_args+=("$url" "-o" "$archive_path")

  # shellcheck disable=SC2046
  eval curl $(printf ' "%s" ' "${curl_args[@]}") && echo "$archive_path" || echo ""
}

asdf_nim_bootstrap_nim() {
  cd "$ASDF_DOWNLOAD_PATH" || exit

  local nim
  nim="./bin/nim"
  if [ ! -f "$nim" ]; then
    if [ -f "build.sh" ]; then
      # source directory has build.sh to build koch, nim, and tools.
      step_start "./build.sh"
      sh build.sh
      step_end "✓"
    elif [ -f "build_all.sh" ]; then
      # source directory has build_all.sh to build koch, nim, and tools.
      step_start "./build_all.sh"
      sh build_all.sh
      step_end "✓"
    else
      step_start "nim already built"
      step_end "✓"
    fi
  else
    step_start "nim already built"
    step_end "✓"
  fi

  [ -f "$nim" ] # A nim executable must exist at this point to proceed
  [ -f "./koch" ] || asdf_nim_build_koch "$nim"
  [ -f "./bin/nim" ] || asdf_nim_build_nim
}

asdf_nim_build_koch() {
  local nim
  nim="$1"
  step_start "build koch"
  cd "$ASDF_DOWNLOAD_PATH" || exit
  # shellcheck disable=SC2046
  eval "$nim" c --skipParentCfg:on $(printf ' %q ' "${NIM_ARGS[@]}") koch
  step_end "✓"
}

asdf_nim_build_nim() {
  step_start "build nim"
  cd "$ASDF_DOWNLOAD_PATH" || exit
  # shellcheck disable=SC2046
  eval ./koch boot $(printf ' %q ' "${NIM_ARGS[@]}")
  step_end "✓"
}

asdf_nim_build_tools() {
  step_start "build tools"
  cd "$ASDF_DOWNLOAD_PATH" || exit
  # shellcheck disable=SC2046
  eval ./koch tools $(printf ' %q ' "${NIM_ARGS[@]}")
  step_end "✓"
}

asdf_nim_build_nimble() {
  step_start "build nimble"
  cd "$ASDF_DOWNLOAD_PATH" || exit
  # shellcheck disable=SC2046
  eval ./koch nimble $(printf ' %q ' "${NIM_ARGS[@]}")
  step_end "✓"
}

# Build Nim binaries in ASDF_NIM_DOWNLOAD_PATH.
asdf_nim_build() {
  section_start "II.  Build (${ASDF_DOWNLOAD_PATH//${HOME}/\~})"

  cd "$ASDF_DOWNLOAD_PATH" || exit
  local bootstrap
  bootstrap=n
  local build_tools
  build_tools=n
  local build_nimble
  build_nimble=n
  [ -f "./bin/nim" ] || bootstrap=y
  [ -f "./bin/nimgrep" ] || build_tools=y
  [ -f "./bin/nimble" ] || build_nimble=y

  if [ "$bootstrap" = "n" ] && [ "$build_tools" = "n" ] && [ "$build_nimble" = "n" ]; then
    step_start "already built"
    step_end "✓"
    return 0
  fi

  [ "$bootstrap" = "n" ] || asdf_nim_bootstrap_nim
  [ "$build_tools" = "n" ] || asdf_nim_build_tools
  [ "$build_nimble" = "n" ] || asdf_nim_build_nimble
}

asdf_nim_time() {
  local start
  start="$(cat "${ASDF_NIM_TEMP}/download.start" 2>/dev/null || true)"
  if [ -n "$start" ]; then
    local now
    now="$(date +%s)"
    local secs
    secs="$((now - start))"
    local mins
    mins="0"
    if [[ $secs -ge 60 ]]; then
      local time_mins
      time_mins="$(echo "scale=2; ${secs}/60" | bc)"
      mins="$(echo "${time_mins}" | cut -d'.' -f1)"
      secs="0.$(echo "${time_mins}" | cut -d'.' -f2)"
      secs="$(echo "${secs}"*60 | bc | awk '{print int($1+0.5)}')"
    fi
    echo " in ${mins}m${secs}s"
  fi
}
