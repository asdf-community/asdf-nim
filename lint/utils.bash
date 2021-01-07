#!/usr/bin/env bash

lint_prettier() {
  local path
  path="$1"
  (
    npx prettier -u -w "$path" 2>&1 1>/dev/null
  ) && (
    echo "↳ prettier     ok"
  ) || (
    echo "↳ prettier     wrote"
  )
}

lint_bash() {
  local path
  path="$1"
  (
    shfmt -d -i 2 -ci -ln bash -w "$path" >/dev/null
  ) && (
    echo "↳ shfmt        ok"
  ) || (
    git add "$path"
    echo "↳ shfmt        wrote"
  )
  patchfile="$(mktemp)"
  (
    shellcheck \
      --format=diff \
      --external-sources \
      --shell=bash \
      --severity=style \
      --exclude=SC2164 \
      "$path" \
      2>/dev/null >"$patchfile"

    if [ -n "$(cat "$patchfile")" ]; then
      git apply "$patchfile" >/dev/null
      git add "$path"
      echo "↳ shellcheck   wrote"
    else
      echo "↳ shellcheck   ok"
    fi
  ) || (
    echo "↳ shellcheck couldn't apply patch"
    cat "$patchfile"
  )
  rm "$patchfile"
}

lint_bats() {
  local path
  path="$1"
  (
    shfmt -d -i 2 -ci -ln bats -w "$path" >/dev/null
  ) && (
    echo "↳ shfmt        ok"
  ) || (
    echo "↳ shfmt        wrote"
    git add "$path"
  )
}

lint() {
  local path
  path="$1"
  local fully_staged_only
  fully_staged_only="${2:-no}"
  echo "# $path"
  if [ "$fully_staged_only" = "yes" ] &&
    [ -n "$(git diff --name-only | grep -F "$path")" ]; then
    # path has unstaged changes, so don't modify it
    echo "↳ unstaged changes, skipping"
    echo
    continue
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
