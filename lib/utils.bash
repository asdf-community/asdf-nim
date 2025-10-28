#!/usr/bin/env bash

# shellcheck disable=SC2230

# Constants
SOURCE_REPO="https://github.com/nim-lang/Nim.git"
SOURCE_URL="https://nim-lang.org/download/nim-VERSION.tar.xz"

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

# Echo the official binary archive URL (from nim-lang.org) for the current
# architecture.
asdf_nim_official_archive_url() {
  if [ "${ASDF_INSTALL_TYPE}" = "version" ] && [[ ${ASDF_INSTALL_VERSION} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    case "$(asdf_nim_normalize_os)" in
      linux)
        # Official Linux builds are available for x86_64 and x86
        case "$(asdf_nim_normalize_arch)" in
          x86_64) echo "${LINUX_X64_URL//VERSION/$ASDF_INSTALL_VERSION}" ;;
          i686) echo "${LINUX_X32_URL//VERSION/$ASDF_INSTALL_VERSION}" ;;
        esac
        ;;
    esac
  fi
}

# Echo the nightly url for arch/os
# Dynamically detects available nightly releases from GitHub
asdf_nim_nightly_url() {
  if [ "${ASDF_INSTALL_TYPE}" != "ref" ]; then
    return 0
  fi
  if [[ $ASDF_INSTALL_VERSION =~ ^version-[0-9]+-[0-9]+$ ]] || [ "$ASDF_INSTALL_VERSION" = "devel" ]; then
    # Try to find a nightly release for this branch and platform
    local url
    url="$(asdf_nim_find_nightly_release_url "$ASDF_INSTALL_VERSION")"
    if [ -n "$url" ]; then
      echo "$url"
    fi
    # If no URL found, return nothing and let the download fallback to git
  fi
}

asdf_nim_github_token() {
  echo "${GITHUB_TOKEN:-${GITHUB_API_TOKEN-}}"
}

# Fetch GitHub releases from nim-lang/nightlies repo
# Fetches up to MAX_PAGES pages (default 4) with 100 releases per page
# Returns JSON array of releases
asdf_nim_fetch_nightly_releases() {
  local max_pages="${1:-4}"
  local releases_repo="https://api.github.com/repos/nim-lang/nightlies/releases"
  local all_releases=""

  for page in $(seq 1 "$max_pages"); do
    local url="${releases_repo}?per_page=100&page=${page}"

    declare -a curl_args
    curl_args=("-fsSL" "--connect-timeout" "10")

    if [ -n "$(asdf_nim_github_token)" ]; then
      curl_args+=("-H" "Authorization: token $(asdf_nim_github_token)")
    fi

    curl_args+=("$url")

    # shellcheck disable=SC2046
    local page_result
    page_result=$(eval curl "$(printf ' "%s" ' "${curl_args[@]}")" 2>/dev/null) || return 1

    # Check if we got an empty array (no more releases)
    if [ "$page_result" = "[]" ]; then
      break
    fi

    # Append to all_releases
    if [ -z "$all_releases" ]; then
      all_releases="$page_result"
    else
      # Merge JSON arrays (remove closing ] from first, opening [ from second)
      local page_without_bracket
      page_without_bracket="${page_result#\[}"
      all_releases="${all_releases%]},${page_without_bracket}"
    fi
  done

  echo "$all_releases"
}

# Extract branch name from release tag (e.g., "latest-devel" -> "devel", "latest-version-2-2" -> "version-2-2")
asdf_nim_extract_branch_from_tag() {
  local tag="$1"
  echo "$tag" | sed 's/^latest-//'
}

# Get platform filename from normalized OS and arch
# Returns the expected filename pattern in nightly releases (e.g., "linux_x64.tar.xz", "macosx_arm64.tar.xz")
asdf_nim_get_platform_filename() {
  local os
  os="$(asdf_nim_normalize_os)"
  local arch
  arch="$(asdf_nim_normalize_arch)"

  case "$os" in
    linux)
      case "$arch" in
        x86_64) echo "linux_x64.tar.xz" ;;
        i686) echo "linux_x32.tar.xz" ;;
        aarch64) echo "linux_arm64.tar.xz" ;;
        armv7) echo "linux_armv7l.tar.xz" ;;
      esac
      ;;
    macos)
      case "$arch" in
        x86_64) echo "macosx_x64.tar.xz" ;;
        arm64) echo "macosx_arm64.tar.xz" ;;
      esac
      ;;
  esac
}

# Find the best matching nightly release URL for the given branch and platform
# Args: $1 = desired branch (e.g., "devel", "version-2-2")
# Returns: URL to download, or empty string if not found
asdf_nim_find_nightly_release_url() {
  local desired_branch="$1"
  local platform_filename
  platform_filename="$(asdf_nim_get_platform_filename)"

  # If we don't have a platform filename, this platform isn't supported for nightlies
  if [ -z "$platform_filename" ]; then
    return 0
  fi

  # Fetch releases
  local releases
  releases="$(asdf_nim_fetch_nightly_releases 4)" || return 1

  # Parse releases to find matching branch with desired platform
  # Simple JSON parsing using grep and sed (works without jq)
  # Strategy: Find lines with tag_name matching our branch, then find browser_download_url
  # lines with our platform filename within the same release

  local desired_tag="latest-${desired_branch}"

  # Find the browser_download_url for our platform within the release with our tag
  # We'll process the entire JSON, tracking when we're in the right release
  local in_target_release=0

  while IFS= read -r line; do
    # Check if this line has a tag_name
    if echo "$line" | grep -q '"tag_name"'; then
      local tag
      tag=$(echo "$line" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

      # Are we entering the target release?
      if [ "$tag" = "$desired_tag" ]; then
        in_target_release=1
      else
        # If we were in the target release and now see a different tag, we're done
        if [ "$in_target_release" -eq 1 ]; then
          break
        fi
      fi
    fi

    # If we're in the target release, look for our platform filename in browser_download_url
    if [ "$in_target_release" -eq 1 ]; then
      if echo "$line" | grep -q "\"browser_download_url\".*${platform_filename}"; then
        local url
        url=$(echo "$line" | sed -n 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        if [ -n "$url" ]; then
          echo "$url"
          return 0
        fi
      fi
    fi
  done <<<"$releases"

  # No match found
  return 0
}

# Convert a version number to a branch name
# Args: $1 = version (e.g., "2.2.4", "1.6.20")
# Returns: branch name (e.g., "version-2-2", "version-1-6")
asdf_nim_version_to_branch() {
  local version="$1"
  # Extract major and minor version numbers
  local major minor
  major=$(echo "$version" | cut -d. -f1)
  minor=$(echo "$version" | cut -d. -f2)
  echo "version-${major}-${minor}"
}

# Get commit hash and date for a version tag
# Args: $1 = version (e.g., "2.2.4")
# Returns: "commit_hash commit_date" or empty string if not found
asdf_nim_get_version_commit_info() {
  local version="$1"
  local tag="v${version}"
  local cache_dir="${HOME}/.cache/asdf-nim"
  local cache_file="${cache_dir}/version-commits.txt"

  # Create cache directory if it doesn't exist
  mkdir -p "$cache_dir"

  # Check cache first
  if [ -f "$cache_file" ]; then
    local cached_info
    cached_info=$(grep "^${version} " "$cache_file" 2>/dev/null | head -1)
    if [ -n "$cached_info" ]; then
      # Extract commit_hash and commit_date from cached line
      echo "$cached_info" | awk '{print $2, $3}'
      return 0
    fi
  fi

  # Not in cache, fetch from git
  # Get commit hash for the tag
  local commit_line
  commit_line=$(git ls-remote --tags "$SOURCE_REPO" "refs/tags/${tag}^{}" 2>/dev/null | head -1)

  if [ -z "$commit_line" ]; then
    return 1
  fi

  local commit_hash
  commit_hash=$(echo "$commit_line" | awk '{print $1}')

  # Get commit date using git show with a shallow fetch
  # We'll use a temporary directory to avoid polluting the current repo
  local temp_dir
  temp_dir=$(mktemp -d)
  local commit_date
  commit_date=$(
    cd "$temp_dir" || exit 1
    git init --quiet
    git remote add origin "$SOURCE_REPO"
    if git fetch --depth 1 origin "$commit_hash" 2>/dev/null; then
      git show -s --format=%ci "$commit_hash" 2>/dev/null | cut -d' ' -f1
    fi
  ) 2>/dev/null

  rm -rf "$temp_dir"

  if [ -n "$commit_date" ]; then
    # Store in cache
    echo "${version} ${commit_hash} ${commit_date}" >>"$cache_file"
    echo "${commit_hash} ${commit_date}"
    return 0
  fi

  return 1
}

# Find exact nightly build matching a specific version
# Args: $1 = version (e.g., "2.2.4")
# Returns: URL to download, or empty string if not found
asdf_nim_find_exact_nightly_url() {
  local version="$1"

  # Skip if opt-out is enabled
  if [ "${ASDF_NIM_NO_NIGHTLY_FALLBACK:-0}" = "1" ] || [ "${ASDF_NIM_NO_NIGHTLY_FALLBACK:-0}" = "true" ]; then
    return 0
  fi

  # Get platform filename
  local platform_filename
  platform_filename="$(asdf_nim_get_platform_filename)"

  if [ -z "$platform_filename" ]; then
    return 0
  fi

  # Get branch name from version
  local branch
  branch=$(asdf_nim_version_to_branch "$version")

  # Get commit info
  local commit_info commit_hash commit_date
  commit_info=$(asdf_nim_get_version_commit_info "$version")

  if [ -z "$commit_info" ]; then
    return 0
  fi

  commit_hash=$(echo "$commit_info" | awk '{print $1}')
  commit_date=$(echo "$commit_info" | awk '{print $2}')

  # Search for nightly with matching commit hash
  # Try dates in order: +1, +0, +2, -1, -2 (based on testing, +1 is most common)
  local offsets="1 0 2 -1 -2"
  local check_date

  for offset in $offsets; do
    # Calculate date with offset
    if [[ "$OSTYPE" == "darwin"* ]]; then
      # macOS date needs explicit + for positive offsets
      local offset_arg="${offset}d"
      if [[ ! "$offset" =~ ^- ]]; then
        offset_arg="+${offset}d"
      fi
      check_date=$(date -j -v"${offset_arg}" -f "%Y-%m-%d" "$commit_date" "+%Y-%m-%d" 2>/dev/null)
    else
      check_date=$(date -d "$commit_date $offset days" "+%Y-%m-%d" 2>/dev/null)
    fi

    if [ -z "$check_date" ]; then
      continue
    fi

    # Construct potential nightly tag
    local nightly_tag="${check_date}-${branch}-${commit_hash}"
    local nightly_url="https://github.com/nim-lang/nightlies/releases/download/${nightly_tag}/nim-${version}-${platform_filename}"

    # Check if this URL exists
    if curl -fsSL -I "$nightly_url" 2>/dev/null | head -1 | grep -q "200\|302"; then
      # Store the nightly tag for informational message later
      echo "$nightly_url"
      export ASDF_NIM_EXACT_NIGHTLY_TAG="$nightly_tag"
      export ASDF_NIM_EXACT_NIGHTLY_VERSION="$version"
      return 0
    fi
  done

  # No match found
  return 0
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
  # Official binaries (x86_64 Linux only)
  asdf_nim_official_archive_url
  # Exact nightly match for stable versions (all platforms)
  if [ "${ASDF_INSTALL_TYPE}" = "version" ] && [[ ${ASDF_INSTALL_VERSION} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    asdf_nim_find_exact_nightly_url "$ASDF_INSTALL_VERSION"
  fi
  # Generic nightly binaries (ref: versions only)
  asdf_nim_nightly_url
  # Fall back to building from source
  asdf_nim_source_url
}

asdf_nim_download_via_git() {
  step_start "git clone"
  rm -rf "$ASDF_NIM_DOWNLOAD_PATH"
  mkdir -p "$ASDF_NIM_DOWNLOAD_PATH"
  local exit_code=0
  (
    cd "$ASDF_NIM_DOWNLOAD_PATH" || exit
    git init
    git remote add origin "$SOURCE_REPO"
    if ! git fetch origin "$ASDF_INSTALL_VERSION" --depth 1 2>&1; then
      if [[ $ASDF_INSTALL_VERSION =~ ^version-[0-9]+-[0-9]+$ ]]; then
        exit 2
      fi
      exit 1
    fi
    git reset --hard FETCH_HEAD
    chmod -R 700 . # For asdf cleanup
  ) || exit_code=$?

  if [ $exit_code -eq 2 ]; then
    step_end "✗"
    {
      echo ""
      echo "Error: Branch '${ASDF_INSTALL_VERSION}' not found in ${SOURCE_REPO}"
      echo ""
    } 1>&"${ASDF_NIM_STDERR:-2}"
    return 1
  elif [ $exit_code -ne 0 ]; then
    step_end "✗"
    return 1
  fi

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
        # Show warning if this looks like a nightly branch but we couldn't find a release
        if [[ $ASDF_INSTALL_VERSION =~ ^version-[0-9]+-[0-9]+$ ]] || [ "$ASDF_INSTALL_VERSION" = "devel" ]; then
          {
            echo ""
            echo "⚠️  No prebuilt nightly release found for ${ASDF_INSTALL_VERSION} on $(asdf_nim_normalize_os)/$(asdf_nim_normalize_arch)"
            echo "    (searched first 4 pages of https://github.com/nim-lang/nightlies/releases)"
            echo ""
            echo "    Falling back to building from source branch..."
            echo ""
          } 1>&"${ASDF_NIM_STDOUT:-1}"
        fi
        asdf_nim_download_via_git
      else
        die "No download method available for ${ASDF_INSTALL_TYPE} ${ASDF_INSTALL_VERSION}"
        return 1
      fi
    else
      # Show informational message if we used an exact nightly match
      if [ -n "${ASDF_NIM_EXACT_NIGHTLY_TAG:-}" ]; then
        {
          echo ""
          echo "ℹ️  Using nightly build for exact version ${ASDF_NIM_EXACT_NIGHTLY_VERSION}"
          echo "    (nightly: ${ASDF_NIM_EXACT_NIGHTLY_TAG})"
          echo ""
        } 1>&"${ASDF_NIM_STDOUT:-1}"
        unset ASDF_NIM_EXACT_NIGHTLY_TAG
        unset ASDF_NIM_EXACT_NIGHTLY_VERSION
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
