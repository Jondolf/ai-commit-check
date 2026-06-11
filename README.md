# AI Commit Check

A GitHub Action that detects AI-authored commits or AI metadata trailers within a commit range.

By default, the action causes a CI check to fail when an AI commit is found.
This behavior can be disabled if you wish to react to the [outputs](#outputs) yourself.

> [!WARNING]
> This action should cover most common AI signature patterns (Claude, Copilot, Cursor, Codex,
> ChatGPT, Gemini, Jules, Devin, Aider) but may not be entirely comprehensive, especially
> as models evolve and change. See [`scripts/check.sh`](scripts/check.sh) for the current
> default patterns. Please [open an issue][new-issue] or a PR if you find patterns that
> were missed, or any false positives!

[new-issue]: https://github.com/Jondolf/ai-commit-check/issues/new

## Usage

```yaml
name: CI

on:
    pull_request:
        branches: [main]

jobs:
    no-ai-commits:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@v4
              with:
                  # Required so the full commit range is available
                  fetch-depth: 0

            - uses: Jondolf/ai-commit-check@v1
```

### Custom Failure

If you want to handle failure manually, you can set `fail-on-detection: false` and use the [outputs](#outputs):

```yaml
- id: ai-check
  uses: Jondolf/ai-commit-check@v1
  with:
      fail-on-detection: false

- if: steps.ai-check.outputs.ai-commits-found == 'true'
  run: echo "::warning::Found ${{ steps.ai-check.outputs.count }} AI commit(s)"
```

## Examples

The action inspects commit metadata (author/committer name and email) and the full commit message, including trailers.
It flags AI signatures, not mentions of AI tools in your subject line.

### Flagged

A commit with an AI co-author trailer:

```
Add retry logic to the HTTP client

Co-authored-by: Claude <noreply@anthropic.com>
```

A commit authored by an AI bot account (matched on the email):

```
Author: github-copilot[bot] <198982749+Copilot@users.noreply.github.com>

Fix off-by-one error in pagination
```

A commit message containing a generated-by footer:

```
Refactor config loading

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

### Not Flagged

A normal human commit:

```
Author: Ada Lovelace <ada@example.com>

Add retry logic to the HTTP client
```

A human commit that merely _mentions_ an AI tool in prose:

```
Author: Ada Lovelace <ada@example.com>

Add Claude API integration

Implements support for the Claude Messages endpoint.
```

A commit with common LLM tropes:

```
Author: Ada Lovelace <ada@example.com>

✨ Add retry logic to the HTTP client

This is a long-overdue improvement — flaky networks were causing
intermittent failures, so requests now retry with backoff. 🚀
```

## Inputs

| Input               | Default                     | Description                                                                                   |
| ------------------- | --------------------------- | --------------------------------------------------------------------------------------------- |
| `base-sha`          | PR base SHA / push `before` | Start of the commit range (exclusive).                                                        |
| `head-sha`          | PR head SHA / push `after`  | End of the commit range (inclusive).                                                          |
| `base-ref`          | PR base ref                 | Base branch name to fetch so the range is reachable.                                          |
| `fail-on-detection` | `true`                      | When `true`, exit non-zero if AI commits are detected. Set to `false` to only report outputs. |
| `pattern`           | built-in                    | Override the regex used to flag AI metadata.                                                  |

## Outputs

| Output             | Description                                        |
| ------------------ | -------------------------------------------------- |
| `ai-commits-found` | `"true"` if any AI-authored commits were detected. |
| `count`            | Number of commits flagged as AI-authored.          |
| `commits`          | Newline-separated list of flagged commit SHAs.     |

## Notes

- Use `fetch-depth: 0` (or a depth large enough to cover the range) in `actions/checkout` so the commits are available.
- Outside of a pull request, the action falls back to checking `HEAD~1..HEAD` unless you pass `base-sha`/`head-sha` explicitly.

## License

The AI Commit Check action is free and open source. All code in this repository is licensed under the MIT License ([LICENSE-MIT](/LICENSE-MIT) or <http://opensource.org/licenses/MIT>).
