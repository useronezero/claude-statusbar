#!/bin/bash
# claude-statusbar — Cross-platform statusline for Claude Code
# https://github.com/useronezero/claude-statusbar
SCRIPT_VERSION="1.0.0"

# Bail gracefully if jq is missing — never crash the statusline
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)

# ─── Catppuccin Mocha palette ────────────────────────────────────────────────
PINK='\033[38;2;245;194;231m'
LAVENDER='\033[38;2;180;190;254m'
GRAY='\033[38;2;108;112;134m'
R='\033[0m'

# Bar colors based on remaining %
C_GREEN='\033[38;2;166;227;161m'
C_YELLOW='\033[38;2;249;226;175m'
C_RED='\033[38;2;243;139;168m'
DIM='\033[38;2;69;71;90m'

SEP="${GRAY} | ${R}"

# ─── Bar renderer ────────────────────────────────────────────────────────────
make_bar() {
    local remaining=$1
    local width=10
    local used=$((100 - remaining))
    local filled=$(( (used * width) / 100 ))
    local empty=$((width - filled))

    local color
    if [ "$remaining" -gt 60 ]; then color="$C_GREEN"
    elif [ "$remaining" -gt 30 ]; then color="$C_YELLOW"
    else color="$C_RED"
    fi

    local bar_filled="" bar_empty=""
    for ((i=0; i<filled; i++)); do bar_filled="${bar_filled}─"; done
    for ((i=0; i<empty; i++)); do bar_empty="${bar_empty}─"; done

    printf "${color}${bar_filled}${DIM}${bar_empty}${R}"
}

# ─── Cross-platform date parsing ─────────────────────────────────────────────
# Converts ISO 8601 timestamp (e.g. "2025-06-15T12:30:00Z") to epoch seconds.
# Tries BSD date first (macOS), then GNU date (Linux).
iso_to_epoch() {
    local iso_str="$1"
    local stripped="${iso_str%%.*}"          # Remove fractional seconds
    stripped="${stripped%%Z}"                 # Remove trailing Z if present

    # Try BSD date (macOS)
    local epoch
    epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
    if [ -n "$epoch" ]; then
        echo "$epoch"
        return 0
    fi

    # Try GNU date (Linux) — accepts ISO format with -d
    epoch=$(date -d "${stripped}" +%s 2>/dev/null)
    if [ -n "$epoch" ]; then
        echo "$epoch"
        return 0
    fi

    return 1
}

# ─── Cross-platform OAuth token resolution ───────────────────────────────────
# Tries credential sources in order: env var → macOS Keychain → Linux creds file → GNOME Keyring
get_oauth_token() {
    local token=""

    # 1. Explicit env var override
    if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
        echo "$CLAUDE_CODE_OAUTH_TOKEN"
        return 0
    fi

    # 2. macOS Keychain
    if command -v security >/dev/null 2>&1; then
        local blob
        blob=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
        if [ -n "$blob" ]; then
            token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                echo "$token"
                return 0
            fi
        fi
    fi

    # 3. Linux credentials file
    local creds_file="${HOME}/.claude/.credentials.json"
    if [ -f "$creds_file" ]; then
        token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
        if [ -n "$token" ] && [ "$token" != "null" ]; then
            echo "$token"
            return 0
        fi
    fi

    # 4. GNOME Keyring via secret-tool
    if command -v secret-tool >/dev/null 2>&1; then
        local blob
        blob=$(timeout 2 secret-tool lookup service "Claude Code-credentials" 2>/dev/null)
        if [ -n "$blob" ]; then
            token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                echo "$token"
                return 0
            fi
        fi
    fi

    echo ""
}

# ─── Usage API ────────────────────────────────────────────────────────────────
CACHE_FILE="${TMPDIR:-/tmp}/claude_statusbar_cache.json"
CACHE_TTL=60

fetch_usage() {
    local now
    now=$(date +%s)

    # Check cache freshness
    if [ -f "$CACHE_FILE" ]; then
        local cached_time
        cached_time=$(jq -r '.timestamp // 0' "$CACHE_FILE" 2>/dev/null)
        local age=$(( now - cached_time ))
        if [ "$age" -lt "$CACHE_TTL" ]; then
            return 0  # cache is fresh
        fi
    fi

    # Get OAuth token via cross-platform resolver
    local token
    token=$(get_oauth_token)
    if [ -z "$token" ] || [ "$token" = "null" ]; then
        echo "{\"timestamp\":$now,\"session_pct\":-1,\"session_reset\":null,\"weekly_pct\":-1,\"weekly_reset\":null,\"extra_used\":-1,\"extra_limit\":-1}" > "$CACHE_FILE"
        return 1
    fi

    # Call usage API
    local resp
    resp=$(curl -s --max-time 5 https://api.anthropic.com/api/oauth/usage \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" 2>/dev/null)
    if [ -z "$resp" ] || ! echo "$resp" | jq -e '.five_hour' >/dev/null 2>&1; then
        echo "{\"timestamp\":$now,\"session_pct\":-1,\"session_reset\":null,\"weekly_pct\":-1,\"weekly_reset\":null,\"extra_used\":-1,\"extra_limit\":-1}" > "$CACHE_FILE"
        return 1
    fi

    # Parse utilization percentages
    local s_pct w_pct
    s_pct=$(echo "$resp" | jq -r '.five_hour.utilization // 0' | awk '{printf "%d", $1}')
    w_pct=$(echo "$resp" | jq -r '.seven_day.utilization // 0' | awk '{printf "%d", $1}')

    # Session (5-hour) reset countdown
    local session_resets_at session_reset_str="null"
    session_resets_at=$(echo "$resp" | jq -r '.five_hour.resets_at // empty')
    if [ -n "$session_resets_at" ]; then
        local reset_epoch
        reset_epoch=$(iso_to_epoch "$session_resets_at")
        if [ -n "$reset_epoch" ]; then
            local diff=$(( reset_epoch - now ))
            if [ "$diff" -gt 0 ]; then
                local h=$(( diff / 3600 ))
                local m=$(( (diff % 3600) / 60 ))
                session_reset_str="\"${h}h $(printf '%02d' $m)m\""
            else
                session_reset_str="\"now\""
            fi
        fi
    fi

    # Weekly (7-day) reset countdown
    local weekly_resets_at weekly_reset_str="null"
    weekly_resets_at=$(echo "$resp" | jq -r '.seven_day.resets_at // empty')
    if [ -n "$weekly_resets_at" ]; then
        local reset_epoch
        reset_epoch=$(iso_to_epoch "$weekly_resets_at")
        if [ -n "$reset_epoch" ]; then
            local diff=$(( reset_epoch - now ))
            if [ "$diff" -gt 0 ]; then
                local d=$(( diff / 86400 ))
                local h=$(( (diff % 86400) / 3600 ))
                weekly_reset_str="\"${d}d ${h}h\""
            else
                weekly_reset_str="\"now\""
            fi
        fi
    fi

    # Extra usage credits
    local extra_used extra_limit
    extra_used=$(echo "$resp" | jq -r '.extra_usage.used_credits // -1' | awk '{printf "%.2f", $1}')
    extra_limit=$(echo "$resp" | jq -r '.extra_usage.monthly_limit // -1' | awk '{printf "%d", $1}')

    # Write cache
    echo "{\"timestamp\":$now,\"session_pct\":$s_pct,\"session_reset\":$session_reset_str,\"weekly_pct\":$w_pct,\"weekly_reset\":$weekly_reset_str,\"extra_used\":$extra_used,\"extra_limit\":$extra_limit}" > "$CACHE_FILE"
}

fetch_usage

# ─── Read cached data ────────────────────────────────────────────────────────
session_pct=""
session_reset=""
weekly_pct=""
weekly_reset=""
if [ -f "$CACHE_FILE" ]; then
    session_pct=$(jq -r '.session_pct // empty' "$CACHE_FILE" 2>/dev/null)
    session_reset=$(jq -r '.session_reset // empty' "$CACHE_FILE" 2>/dev/null)
    weekly_pct=$(jq -r '.weekly_pct // empty' "$CACHE_FILE" 2>/dev/null)
    weekly_reset=$(jq -r '.weekly_reset // empty' "$CACHE_FILE" 2>/dev/null)
fi

# ─── Build output ────────────────────────────────────────────────────────────

# 1. Current directory
cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')
dir=$(basename "$cwd" 2>/dev/null || echo "~")
out="${PINK}${dir}${R}"

# 2. Git branch
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
    [ -n "$branch" ] && out="${out}${SEP}${LAVENDER} ${branch}${R}"
fi

# 3. Context window remaining
ctx=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
if [ -n "$ctx" ]; then
    ctx_bar=$(make_bar "$ctx")
    out="${out}${SEP}Context ${ctx_bar} ${ctx}%"
fi

# 4. Session (5-hour) + reset countdown
if [ -n "$session_pct" ] && [ "$session_pct" != "-1" ]; then
    session_remaining=$((100 - session_pct))
    session_bar=$(make_bar "$session_remaining")
    reset_txt=""
    [ -n "$session_reset" ] && [ "$session_reset" != "null" ] && reset_txt=" ${session_reset}"
    out="${out}${SEP}Session ${session_bar} ${session_pct}%${reset_txt}"
fi

# 5. Weekly (7-day) + reset countdown
if [ -n "$weekly_pct" ] && [ "$weekly_pct" != "-1" ]; then
    weekly_remaining=$((100 - weekly_pct))
    weekly_bar=$(make_bar "$weekly_remaining")
    reset_txt=""
    [ -n "$weekly_reset" ] && [ "$weekly_reset" != "null" ] && reset_txt=" ${weekly_reset}"
    out="${out}${SEP}Weekly ${weekly_bar} ${weekly_pct}%${reset_txt}"
fi

# 6. Model name
model=$(echo "$input" | jq -r '.model.display_name // empty')
[ -n "$model" ] && out="${out}${SEP}${LAVENDER}${model}${R}"

# 7. Extra usage credits (spent / balance) — API values are in cents
extra_used=$(jq -r '.extra_used // empty' "$CACHE_FILE" 2>/dev/null)
extra_limit=$(jq -r '.extra_limit // empty' "$CACHE_FILE" 2>/dev/null)
if [ -n "$extra_used" ] && [ -n "$extra_limit" ] && [ "$extra_limit" != "-1" ]; then
    spent=$(awk "BEGIN {printf \"%.2f\", $extra_used / 100}")
    balance=$(awk "BEGIN {printf \"%.2f\", ($extra_limit - $extra_used) / 100}")
    out="${out}${SEP}${C_YELLOW}\$${spent}${GRAY}/${C_GREEN}\$${balance}${R}"
fi

printf '%b' "$out"
