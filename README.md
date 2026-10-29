# Praxis Factory Review

Praxis Factory Review is a multi-lens pull request review that runs in your own GitHub Actions. It ships as a Claude Code plugin and a composite action. Six lenses (architecture, readability, testing, maintainability, security, documentation) each run as a read-only subagent. One orchestrator verifies their findings, drops what it cannot defend, and posts the rest as [Conventional Comments](https://conventionalcomments.org/).

Built by [Praxis Forward](https://www.praxisforward.ai).

## Set up the action

1. Add a model credential as a repository secret. Use `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`) or `ANTHROPIC_API_KEY`.
2. Copy [`examples/praxis-factory-review.yml`](examples/praxis-factory-review.yml) to `.github/workflows/praxis-factory-review.yml` in your repository.
3. Open a pull request. A check named **Praxis Factory Review** posts inline comments, then one summary comment.

The core of the workflow:

```yaml
jobs:
  review:
    name: Praxis Factory Review
    runs-on: ubuntu-latest
    timeout-minutes: 30
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}
      - uses: PraxisForward/praxis-factory-review@v0.1.0
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

Check out the pull request head SHA, not the default merge ref, so comment line numbers match the diff.

### Inputs

| Input | Purpose |
| --- | --- |
| `claude_code_oauth_token` | Claude Code OAuth token. |
| `anthropic_api_key` | Anthropic API key. |
| `use_bedrock`, `use_vertex` | Use Amazon Bedrock or Google Vertex AI over OIDC. Add `id-token: write` to the job permissions. |
| `github_token` | Token that reads the pull request and posts comments. Defaults to the workflow's `GITHUB_TOKEN`, which posts as `github-actions[bot]`. |
| `claude_args` | Extra Claude Code CLI arguments. |

### Limits

- Fork pull requests receive no secrets, so the example workflow skips them. Do not switch to `pull_request_target`, which hands secrets to a run that reads untrusted code.
- The review comments but does not approve or request changes.
- Each push reviews the new head and posts a new set of comments. Earlier comments are not updated.
- The review fails when the checkout is not the pull request's current head, for example on a rerun of an older push. This keeps the diff and the source files the lenses read on one revision.

## How it works

The action pins the plugin to its own version. When a workflow uses `PraxisForward/praxis-factory-review@<tag>`, GitHub downloads this repository at that tag. The action registers that local copy as a plugin marketplace, so the lenses and skills always match the action's tag.

1. A prepare step writes the pull request metadata and diff to `.praxis-review/` in the checkout.
2. `claude-code-action` runs the `review-pr-ci` skill. It never asks questions and never waits for approval.
3. The skill dispatches the six lens subagents at once. Each lens has only `Read`, `Grep`, and `Glob`, so it cannot post, edit, or run commands. Each returns a structured report in the shape the `review-contract` skill defines.
4. The orchestrator names any lens that returned no report or an incomplete one in the summary. It verifies every candidate finding against the code, dedupes across lenses, and cuts findings an author would not act on.
5. It posts each surviving finding as an inline comment and finishes with one summary comment.

```
action.yml                          composite action
.claude-plugin/marketplace.json     makes this repository a plugin marketplace
plugins/praxis-factory-review/
  agents/                           one read-only subagent per lens
  skills/review-pr-ci/              orchestrator, the only part that posts
  skills/review-contract/           preloaded into every lens
  skills/conventional-comments/     comment format
  profiles/                         stack review profiles (Rails)
  scripts/prepare-review.sh         writes the review inputs
```

## Use the plugin in Claude Code

```
/plugin marketplace add PraxisForward/praxis-factory-review
/plugin install praxis-factory-review@praxis-factory-review
```

To dry-run the CI review locally against a pull request checked out at its head:

```sh
plugins/praxis-factory-review/scripts/prepare-review.sh <pr-number> <owner/repo>
claude -p "/praxis-factory-review:review-pr-ci <owner/repo> <pr-number> --dry-run" \
  --allowedTools "Agent,Skill,Read,Grep,Glob"
```

A dry run prints the comments it would post and posts nothing.

## Tuning and rollout

Praxis Forward tunes the lenses to a team's codebase and rolls the review out across an organization. Get in touch at [praxisforward.ai](https://www.praxisforward.ai).
