# claude-statusbar

Custom statusline script for Claude Code showing usage data from the Anthropic API.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/useronezero/claude-statusbar/main/install.sh | bash
```

Requires `jq` and `curl`. Restart Claude Code after installing.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/useronezero/claude-statusbar/main/uninstall.sh | bash
```

## File locations

- Script: `~/.claude/statusline.sh`
- Settings: `~/.claude/settings.json` (the `statusLine` key)
- Cache: `${TMPDIR:-/tmp}/claude_statusbar_cache.json`

## Troubleshooting

If the statusline is blank:
1. Verify jq is installed: `jq --version`
2. Verify the script exists: `ls -la ~/.claude/statusline.sh`
3. Test it manually: `echo '{}' | bash ~/.claude/statusline.sh`
4. Check settings: `cat ~/.claude/settings.json` — should have `statusLine` config
5. Delete cache to force refresh: `rm ${TMPDIR:-/tmp}/claude_statusbar_cache.json`

If usage data is missing but context/model show:
- The OAuth token may not be resolving. Ensure the user is logged into Claude Code.
- On Linux, check that `~/.claude/.credentials.json` exists.

## Architecture

- Reads JSON from stdin (provided by Claude Code)
- Fetches `/api/oauth/usage` with cached OAuth token
- Caches API response for 60s
- Outputs ANSI-colored statusline via printf
