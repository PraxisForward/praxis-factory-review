#!/usr/bin/env bash
# Writes the review inputs into .praxis-review/ in the current checkout so the
# read-only lenses can Read them. Lenses have no Bash, so they cannot fetch the
# diff themselves.
set -euo pipefail

pr="${1:?usage: prepare-review.sh <pr-number> [owner/repo]}"
repo="${2:-${GITHUB_REPOSITORY:?pass owner/repo or set GITHUB_REPOSITORY}}"
plugin_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out=".praxis-review"

rm -rf "$out"
mkdir -p "$out"

gh pr view "$pr" --repo "$repo" \
  --json number,title,body,author,baseRefName,baseRefOid,headRefName,headRefOid,isDraft,files \
  > "$out/pr.json"
gh pr diff "$pr" --repo "$repo" > "$out/pr.diff"

if [[ -f Gemfile ]] && grep -qE "^\s*gem ['\"]rails['\"]" Gemfile; then
  cp "$plugin_root/profiles/rails.md" "$out/profile.md"
fi

echo "Prepared PR #$pr: $(wc -l < "$out/pr.diff" | tr -d ' ') diff lines, profile: $([[ -f "$out/profile.md" ]] && echo rails || echo none)"
