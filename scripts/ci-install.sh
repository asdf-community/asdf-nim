#!/bin/bash

# CI script to install golang and asdf.
# Only used on Linux / non-x86 architectures.
# This is used in the "install" stage of the run-on-arch-action GitHub workflow.

set -uexo pipefail

export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export PATH="/root/go/bin:${PATH}"

# Install basic dependencies
apt-get update -q -y
apt-get -qq install -y ca-certificates curl gnupg

update-ca-certificates || true

# Install apt-fast for faster package downloads
cat >/etc/apt/sources.list.d/apt-fast.list <<EOF
deb [signed-by=/etc/apt/keyrings/apt-fast.gpg] http://ppa.launchpad.net/apt-fast/stable/ubuntu focal main
EOF
mkdir -p /etc/apt/keyrings
curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xBC5934FD3DEBD4DAEA544F791E2824A7F22B44BD" | gpg --dearmor -o /etc/apt/keyrings/apt-fast.gpg
apt-get update -q -y
apt-get install -qq -y apt-fast

# Add Debian backports repository for newer Golang versions
cat >/etc/apt/sources.list.d/debian-backports.sources <<EOF
Types: deb deb-src
URIs: http://deb.debian.org/debian
Suites: bookworm-backports
Components: main
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

apt-get update -q -y
apt-fast install -qq -y git xz-utils build-essential
apt-fast install -qq -y -t bookworm-backports golang-go

# Install asdf
go install github.com/asdf-vm/asdf/cmd/asdf@master
