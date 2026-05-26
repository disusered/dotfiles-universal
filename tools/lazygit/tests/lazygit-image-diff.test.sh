#!/usr/bin/env sh
set -eu

SCRIPT="${SCRIPT:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/lazygit-image-diff}"
TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT INT HUP TERM

assert_contains() {
  file=$1
  expected=$2

  if ! grep -F -- "$expected" "$file" >/dev/null; then
    echo "Expected $file to contain: $expected" >&2
    echo "--- $file ---" >&2
    cat "$file" >&2
    exit 1
  fi
}

assert_not_contains() {
  file=$1
  unexpected=$2

  if grep -F -- "$unexpected" "$file" >/dev/null; then
    echo "Expected $file not to contain: $unexpected" >&2
    echo "--- $file ---" >&2
    cat "$file" >&2
    exit 1
  fi
}

run_case() {
  name=$1
  shift

  tmp="$TEST_TMP/$name"

  mkdir -p "$tmp/bin"
  log="$tmp/git.log"
  output="$tmp/output.log"
  : > "$log"

  cat > "$tmp/bin/git" <<'EOF'
#!/usr/bin/env sh
set -eu

printf 'git' >> "$LAZYGIT_IMAGE_DIFF_TEST_LOG"
for arg in "$@"; do
  printf ' %s' "$arg" >> "$LAZYGIT_IMAGE_DIFF_TEST_LOG"
done
printf '\n' >> "$LAZYGIT_IMAGE_DIFF_TEST_LOG"

if [ "$1" = "check-attr" ]; then
  path=$4
  case "$path" in
    *.png|*.PNG)
      printf '%s: diff: image\n' "$path"
      ;;
    *)
      printf '%s: diff: unspecified\n' "$path"
      ;;
  esac
  exit 0
fi

if [ "$1" = "difftool" ]; then
  exit 0
fi

exit 2
EOF

  cat > "$tmp/bin/kitten" <<'EOF'
#!/usr/bin/env sh
exit 0
EOF

  chmod +x "$tmp/bin/git" "$tmp/bin/kitten"

  PATH="$tmp/bin:$PATH" LAZYGIT_IMAGE_DIFF_TEST_LOG="$log" "$SCRIPT" "$@" > "$output"
}

test_non_image_skips_difftool() {
  run_case non_image worktree -- README.md

  assert_contains "$log" "git check-attr diff -- README.md"
  assert_not_contains "$log" "git difftool"
  assert_contains "$output" "README.md is not configured as an image diff"
}

test_image_attribute_uses_cached_difftool() {
  run_case image_attr cached -- assets/photo.png

  assert_contains "$log" "git check-attr diff -- assets/photo.png"
  assert_contains "$log" "git difftool --cached --tool=kitty-image --no-symlinks -y -- assets/photo.png"
}

test_image_extension_fallback_uses_worktree_difftool() {
  run_case image_ext worktree -- assets/fallback.webp

  assert_contains "$log" "git check-attr diff -- assets/fallback.webp"
  assert_contains "$log" "git difftool --tool=kitty-image --no-symlinks -y -- assets/fallback.webp"
}

test_non_image_skips_difftool
test_image_attribute_uses_cached_difftool
test_image_extension_fallback_uses_worktree_difftool
