#!/usr/bin/env bash

lint_prettier() {
  local path status
  path="$1"
  status=0
  npx prettier -u -w "$path" 1>/dev/null 2>&1 || status=$?
  if [ "$status" = 0 ]; then
    echo "↳ prettier     ok"
  else
    echo "↳ prettier     wrote"
  fi
}

lint_bash() {
  local path status
  path="$1"
  status=0
  shfmt -d -i 2 -ci -ln bash -w "$path" >/dev/null || status=$?
  if [ "$status" = 0 ]; then
    echo "↳ shfmt        ok"
  else
    git add "$path"
    echo "↳ shfmt        wrote"
  fi
  patchfile="$(mktemp)"
  status=0
  shellcheck \
    --format=diff \
    --external-sources \
    --shell=bash \
    --severity=style \
    --exclude=SC2164 \
    "$path" \
    2>/dev/null >"$patchfile" ||
    status=$?
  if [ "$status" = 0 ]; then
    if [ -n "$(cat "$patchfile")" ]; then
      git apply "$patchfile" >/dev/null
      git add "$path"
      echo "↳ shellcheck   wrote"
    else
      echo "↳ shellcheck   ok"
    fi
  else
    echo "↳ shellcheck couldn't apply patch"
    cat "$patchfile"
  fi
  rm "$patchfile"
}

lint_bats() {
  local path status
  path="$1"
  status=0
  shfmt -d -i 2 -ci -ln bats -w "$path" >/dev/null || status=$?
  if [ "$status" = 0 ]; then
    echo "↳ shfmt        ok"
  else
    echo "↳ shfmt        wrote"
    git add "$path"
  fi
}

lint() {
  local path
  path="$1"
  local fully_staged_only
  fully_staged_only="${2:-no}"
  echo "# $path"
  if [ "$fully_staged_only" = "yes" ]; then
    if git diff --name-only | grep -qF "$path"; then
      # path has unstaged changes, so don't modify it
      echo "↳ unstaged changes, skipping"
      echo
      return
    fi
  fi
  case "$path" in
    *.md | *.yml) lint_prettier "$path" ;;
    *.bats) lint_bats "$path" ;;
    *.sh | *.bash) lint_bash "$path" ;;
    *)
      # Inspect hashbang
      case "$(head -n1 "$path")" in
        */bash | *env\ bash | "/bin/sh") lint_bash "$path" ;;
        */bats | *env\ bats) lint_bats "$path" ;;
        *) echo "↳ no linter" ;;
      esac
      ;;
  esac
  echo
}
