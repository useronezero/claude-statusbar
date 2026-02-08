# claude-statusbar

A cross-platform statusline for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that shows real-time usage data from the Anthropic API.

![macOS](https://img.shields.io/badge/macOS-supported-brightgreen) ![Linux](https://img.shields.io/badge/Linux-supported-brightgreen) ![License](https://img.shields.io/badge/license-MIT-blue)

![claude-statusbar preview](preview.png)

## What it shows

| Section | Description |
|---------|-------------|
| Directory | Current working directory name |
| Git branch | Active branch with  icon |
| Context window | Remaining % with color bar |
| Session (5h) | Usage % with bar + reset countdown (e.g. `2h 15m`) |
| Weekly (7d) | Usage % with bar + reset countdown (e.g. `3d 12h`) |
| Model | Current model display name |
| Credits | Extra usage spent / remaining balance |

Bars turn green (>60%), yellow (30-60%), or red (<30%) based on remaining capacity. Styled with the Catppuccin Mocha palette.

## Install

Requires `jq` and `curl`.

```bash
curl -fsSL https://raw.githubusercontent.com/useronezero/claude-statusbar/main/install.sh | bash
```

Then restart Claude Code.

### Install jq

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq

# Fedora
sudo dnf install jq
```

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/useronezero/claude-statusbar/main/uninstall.sh | bash
```

## How it works

1. Claude Code pipes JSON context (workspace, model, context window) to `~/.claude/statusline.sh` via stdin
2. The script calls the Anthropic OAuth usage API (`/api/oauth/usage`) to fetch session and weekly rate limits
3. API responses are cached for 60 seconds to minimize requests
4. OAuth tokens are resolved automatically from your existing Claude Code credentials (Keychain on macOS, credentials file or GNOME Keyring on Linux)
5. Output is formatted with ANSI colors and printed to the statusline

## Configuration

The installer adds this to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash /Users/you/.claude/statusline.sh",
    "refresh": 150
  }
}
```

- `refresh`: How often (in context window ticks) the statusline updates. Lower = more frequent.

## Environment variables

| Variable | Description |
|----------|-------------|
| `CLAUDE_CODE_OAUTH_TOKEN` | Override OAuth token (skips Keychain/credentials file lookup) |

## Credential sources (tried in order)

1. `$CLAUDE_CODE_OAUTH_TOKEN` env var
2. macOS Keychain (`security find-generic-password`)
3. `~/.claude/.credentials.json` (Linux)
4. GNOME Keyring (`secret-tool`)

## Troubleshooting

**Statusline is blank**
- Run `jq --version` to confirm jq is installed
- Check that `~/.claude/statusline.sh` exists and is executable
- Verify `~/.claude/settings.json` has the `statusLine` config

**Usage bars show but no percentages**
- The API call may be failing. Test manually:
  ```bash
  echo '{}' | bash ~/.claude/statusline.sh
  ```
- Check that you're logged into Claude Code (the script reads your OAuth token automatically)

**Stale data**
- Cache is at `${TMPDIR:-/tmp}/claude_statusbar_cache.json` — delete it to force a refresh

## Requirements

- Claude Code with an active subscription
- `jq` (JSON processor)
- `curl`
- `bash` 4+

## License

MIT
