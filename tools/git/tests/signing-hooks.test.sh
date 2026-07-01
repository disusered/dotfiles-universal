#!/bin/sh
set -eu

repo=$(mktemp -d)
trap 'rm -rf "$repo"' EXIT

hook_dir=$(cd "$(dirname "$0")/.." && pwd)/hooks

git -C "$repo" init -q
git -C "$repo" config user.name "Carlos Rosquillas"
git -C "$repo" config user.email "crosquillas@gmail.com"
git -C "$repo" config commit.gpgsign false

make_commit() {
  name=$1
  email=$2
  message=$3

  printf '%s\n' "$message" >"$repo/file.txt"
  git -C "$repo" add file.txt
  GIT_AUTHOR_NAME=$name \
    GIT_AUTHOR_EMAIL=$email \
    GIT_COMMITTER_NAME=$name \
    GIT_COMMITTER_EMAIL=$email \
    git -C "$repo" -c core.hooksPath=/dev/null commit -q -m "$message"
}

run_pre_push() {
  local_sha=$1
  remote_sha=$2

  printf 'refs/heads/main %s refs/heads/main %s\n' "$local_sha" "$remote_sha" |
    (cd "$repo" && "$hook_dir/pre-push")
}

run_post_commit() {
  (cd "$repo" && "$hook_dir/post-commit")
}

run_pre_push_skipped() {
  local_sha=$1
  remote_sha=$2

  printf 'refs/heads/main %s refs/heads/main %s\n' "$local_sha" "$remote_sha" |
    (cd "$repo" && SKIP_SIGNING_HOOKS=1 "$hook_dir/pre-push")
}

run_post_commit_skipped() {
  (cd "$repo" && SKIP_SIGNING_HOOKS=1 "$hook_dir/post-commit")
}

zero_sha=0000000000000000000000000000000000000000

make_commit "Team Member" "teammate@example.com" "team commit"
team_commit=$(git -C "$repo" rev-parse HEAD)

if ! run_post_commit; then
  echo "expected teammate-authored unsigned commit to be ignored by post-commit" >&2
  exit 1
fi

if [ "$(git -C "$repo" rev-parse HEAD)" != "$team_commit" ]; then
  echo "expected teammate-authored commit to remain HEAD after post-commit" >&2
  exit 1
fi

if ! run_pre_push "$team_commit" "$zero_sha"; then
  echo "expected teammate-authored unsigned commit to be ignored" >&2
  exit 1
fi

make_commit "Carlos Rosquillas" "crosquillas@gmail.com" "carlos commit"
carlos_commit=$(git -C "$repo" rev-parse HEAD)

if ! run_pre_push_skipped "$carlos_commit" "$team_commit"; then
  echo "expected own unsigned commit to be skipped by pre-push escape hatch" >&2
  exit 1
fi

if ! run_post_commit_skipped; then
  echo "expected own unsigned commit to be skipped by post-commit escape hatch" >&2
  exit 1
fi

if [ "$(git -C "$repo" rev-parse HEAD)" != "$carlos_commit" ]; then
  echo "expected skipped own unsigned commit to remain HEAD after post-commit" >&2
  exit 1
fi

if run_pre_push "$carlos_commit" "$team_commit"; then
  echo "expected own unsigned commit to be rejected" >&2
  exit 1
fi

if run_post_commit; then
  echo "expected own unsigned commit to be rejected by post-commit" >&2
  exit 1
fi

if [ "$(git -C "$repo" rev-parse HEAD)" != "$team_commit" ]; then
  echo "expected own unsigned commit to be rewound by post-commit" >&2
  exit 1
fi
