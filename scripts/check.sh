#!/usr/bin/env bash
set -euo pipefail

# Inputs are passed in via environment variables (see action.yml).
BASE_SHA="${AICC_BASE_SHA:-}"
HEAD_SHA="${AICC_HEAD_SHA:-}"
BASE_REF="${AICC_BASE_REF:-}"
FAIL_ON_DETECTION="${AICC_FAIL_ON_DETECTION:-true}"
PATTERN="${AICC_PATTERN:-}"

# git uses an all-zero SHA to mean "no commit" or "empty tree".
ZERO_SHA="0000000000000000000000000000000000000000"

# Default detection pattern. Flags common AI metadata signatures.
# These are based on https://botcommits.dev, the documentation of each AI platform,
# and some other miscellaneous references. Feel free to add more or fix any false positives!
if [ -z "$PATTERN" ]; then
    PATTERN='(Co-authored-by|Signed-off-by|Authorized-by):.*(Claude|Copilot|Cursor|Codex|ChatGPT|GPT-|Gemini|Jules|Devin|Aider)'
    PATTERN="$PATTERN"'|Generated with (\[)?(Claude Code|Cursor|Copilot)|🤖 Generated'
    PATTERN="$PATTERN"'|claude\.ai/code|claude\.com/claude-code'
    PATTERN="$PATTERN"'|noreply@anthropic\.com|noreply@openai\.com|github-copilot\[bot\]'
    PATTERN="$PATTERN"'|cursoragent|@cursor\.com|devin-ai-integration|@devin\.ai|google-labs-jules|[0-9]+\+Copilot@users\.noreply\.github\.com|\[aider\]|\(aider\)'
fi

# Fetch the base branch.
if [ -n "$BASE_REF" ]; then
    echo "Fetching base branch origin/$BASE_REF..."
    git fetch origin "$BASE_REF" --depth=100 || true
fi

# Determine the commit range to evaluate.
if [ -n "$BASE_SHA" ] && [ "$BASE_SHA" != "$ZERO_SHA" ] && [ -n "$HEAD_SHA" ] && [ "$HEAD_SHA" != "$ZERO_SHA" ]; then
    range="$BASE_SHA..$HEAD_SHA"
else
    range="HEAD~1..HEAD"
fi

echo "Evaluating commit range: $range"

failed=0
count=0
offending=()

# Iterate through commit hashes in the range.
while read -r sha; do
    [ -z "$sha" ] && continue

    # Author name, author email, committer name, committer email, and full body.
    message=$(git log -1 --format='%an%n%ae%n%cn%n%ce%n%B' "$sha")

    if echo "$message" | grep -Eiq "$PATTERN"; then
        echo "::error::Commit $sha appears to be AI-authored or contains AI trailers."
        echo "--------------------------------------------------"
        git log -1 --format='  Commit: %h%n  Author: %an <%ae>%n  Subject: %s%n  Body:%n%b' "$sha"
        echo "--------------------------------------------------"
        failed=1
        count=$((count + 1))
offending+=("$sha")
    fi
done < <(git rev-list "$range")

# Emit step outputs so callers can react to the result.
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    if [ "$failed" -ne 0 ]; then
        echo "ai-commits-found=true" >>"$GITHUB_OUTPUT"
    else
        echo "ai-commits-found=false" >>"$GITHUB_OUTPUT"
    fi
    echo "count=$count" >>"$GITHUB_OUTPUT"
    {
        echo "commits<<__AICC_EOF__"
        if [ "${#offending[@]}" -gt 0 ]; then
            printf '%s\n' "${offending[@]}"
        fi
        echo "__AICC_EOF__"
    } >>"$GITHUB_OUTPUT"
fi

if [ "$failed" -ne 0 ]; then
    echo "Detected $count AI-authored commit(s) in $range."
    if [ "$FAIL_ON_DETECTION" = "true" ]; then
        echo "Error: AI-authored commits are not allowed. Remove or rewrite the offending commits."
        exit 1
    fi
    echo "fail-on-detection is disabled; reporting via the 'ai-commits-found' output instead of failing."
    exit 0
fi

echo "Success: No AI-authored commits found in $range."
