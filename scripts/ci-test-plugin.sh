#!/bin/bash

# CI script to run asdf plugin test

set -uexo pipefail

export PATH="${HOME}/go/bin:${PATH}"

# Parse command line arguments
NIM_VERSION=""
COMMIT=""
WORKSPACE="${PWD}"

usage() {
  echo "Usage: $0 --nim-version VERSION --commit COMMIT --workspace WORKSPACE"
  echo "  --nim-version VERSION   Specify the Nim version to test (e.g., latest:1.4.8)"
  echo "  --commit COMMIT         Specify the commit hash to test (default: current branch HEAD)"
  echo "  --workspace WORKSPACE   Specify the workspace directory containing the plugin (default: current directory)"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --nim-version)
      NIM_VERSION="$2"
      shift 2
      ;;
    --commit)
      COMMIT="$2"
      shift 2
      ;;
    --workspace)
      WORKSPACE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z ${NIM_VERSION} ]]; then
  echo "Error: --nim-version parameter is required"
  usage
  exit 1
fi

if [[ -z ${COMMIT} ]]; then
  COMMIT="${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:-}}"
fi

if [[ -z ${WORKSPACE} ]]; then
  echo "Error: --workspace parameter must not be empty"
  usage
  exit 1
fi

update-ca-certificates || true

if [[ ${NIM_VERSION} == latest:* ]]; then
  # Extract the part after "latest:"
  version_prefix="${NIM_VERSION}"
  version_prefix=${version_prefix#latest:}

  # Run asdf latest command to get the actual version
  asdf plugin add nim .
  tool_version=$(asdf latest nim "$version_prefix")
else
  # Use the matrix version directly
  tool_version="${NIM_VERSION}"
fi

asdf plugin remove asdf-test-nim || true

rm -rf /tmp/asdf-test-nim || true
git config --global --add safe.directory "${WORKSPACE}"/.git
git clone --quiet "${WORKSPACE}" /tmp/asdf-test-nim
cd /tmp/asdf-test-nim || exit 1
git checkout -b tmp-test-branch || true
if [[ -n ${COMMIT} ]]; then
  # Try to reset to commit/branch from origin
  git fetch --quiet origin "${COMMIT}:${COMMIT}" 2>/dev/null || true
  git reset --hard "${COMMIT}" 2>/dev/null || true
fi
asdf plugin test nim "${PWD}" \
  --asdf-tool-version \
  "${tool_version}" \
  --asdf-plugin-gitref \
  tmp-test-branch \
  nim -v
