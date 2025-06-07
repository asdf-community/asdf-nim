#!/bin/bash

# CI script to run asdf plugin test

set -uexo pipefail

# Parse command line arguments
NIM_VERSION=""
COMMIT=""

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
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 --nim-version VERSION"
      exit 1
      ;;
  esac
done

if [[ -z ${NIM_VERSION} ]]; then
  echo "Error: --nim-version parameter is required"
  echo "Usage: $0 --nim-version VERSION --commit COMMIT"
  exit 1
fi

if [[ -z ${COMMIT} ]]; then
  echo "Error: --commit parameter is required"
  echo "Usage: $0 --nim-version VERSION --commit COMMIT"
  exit 1
fi

update-ca-certificates || true

export PATH="${HOME}/go/bin:${PATH}"

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
git clone . /tmp/asdf-test-nim
cd /tmp/asdf-test-nim || exit 1
git checkout -b tmp-test-branch "${COMMIT}" || true
asdf plugin test nim "${PWD}" \
  --asdf-tool-version \
  "${tool_version}" \
  --asdf-plugin-gitref \
  tmp-test-branch \
  nim -v
