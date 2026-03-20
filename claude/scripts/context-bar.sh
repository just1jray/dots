#!/bin/bash
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
    # Status line should fail gracefully if jq isn't installed.
    input=$(cat)
    printf '%s\n' "Claude Code | 📁 ? | jq not found"
    exit 0
fi

# Color theme: gray, orange, blue, teal, green, lavender, rose, gold, slate, cyan
# Catppuccin Mocha: rosewater, flamingo, pink, mauve, red, maroon, peach, yellow, sky, sapphire
# Preview colors with: bash scripts/color-preview.sh
COLOR="orange"

# Randomizer: set to a group name to override COLOR with a random pick each refresh.
# Leave empty "" to use the fixed COLOR above.
# Groups: all, catppuccin, classic, blues, greens, warms, cools, pastel, jewel
RANDOM_COLOR="catppuccin"

# Read stdin early so transcript_path is available for stable color seeding
input=$(cat)

if [[ -n "$RANDOM_COLOR" ]]; then
    case "$RANDOM_COLOR" in
        catppuccin) palette="rosewater flamingo pink mauve red maroon peach yellow sky sapphire" ;;
        classic)    palette="orange blue teal green lavender rose gold slate cyan" ;;
        blues)      palette="blue teal cyan sky sapphire" ;;
        greens)     palette="teal green cyan sky" ;;
        warms)      palette="orange rose gold red maroon peach yellow flamingo rosewater pink" ;;
        cools)      palette="blue teal cyan lavender slate sky sapphire mauve" ;;
        pastel)     palette="rosewater flamingo pink lavender sky" ;;
        jewel)      palette="sapphire mauve maroon teal gold" ;;
        *)          palette="orange blue teal green lavender rose gold slate cyan rosewater flamingo pink mauve red maroon peach yellow sky sapphire" ;;
    esac
    # shellcheck disable=SC2206
    colors=($palette)
    # Seed from transcript path for stable per-session color
    tp=$(echo "$input" | jq -r '.transcript_path // empty')
    if [[ -n "$tp" ]]; then
        hash=$(cksum <<< "$tp" | cut -d' ' -f1)
    else
        hash=$RANDOM
    fi
    COLOR="${colors[hash % ${#colors[@]}]}"
fi

# Color codes
C_RESET='\033[0m'
C_GRAY='\033[38;5;245m'      # explicit gray for default text
C_BAR_EMPTY='\033[38;5;238m'
BAR_FULL='▰'
BAR_HALF='▰'
BAR_EMPTY='▱'

# Catppuccin Mocha true colors (shared by bar gradient, accent selector, and usage stats)
C_GREEN='\033[38;2;166;227;161m'
C_YELLOW='\033[38;2;249;226;175m'
C_PEACH='\033[38;2;250;179;135m'
C_RED='\033[38;2;243;139;168m'
C_MAUVE='\033[38;2;203;166;247m'

# Context bar gradient: green → yellow → peach → red → mauve (Catppuccin Mocha)
C_BAR=(
    "$C_GREEN"
    '\033[38;2;207;226;168m'  # green-yellow
    "$C_YELLOW"
    '\033[38;2;249;202;155m'  # yellow-peach
    "$C_PEACH"
    '\033[38;2;247;166;146m'  # peach-red
    '\033[38;2;245;152;157m'  # light red
    "$C_RED"
    '\033[38;2;223;152;207m'  # red-mauve
    "$C_MAUVE"
)
case "$COLOR" in
    orange)    C_ACCENT='\033[38;5;173m' ;;
    blue)      C_ACCENT='\033[38;5;74m' ;;
    teal)      C_ACCENT='\033[38;5;66m' ;;
    green)     C_ACCENT='\033[38;5;71m' ;;
    lavender)  C_ACCENT='\033[38;5;139m' ;;
    rose)      C_ACCENT='\033[38;5;132m' ;;
    gold)      C_ACCENT='\033[38;5;136m' ;;
    slate)     C_ACCENT='\033[38;5;60m' ;;
    cyan)      C_ACCENT='\033[38;5;37m' ;;
    # Catppuccin Mocha palette (true color)
    rosewater) C_ACCENT='\033[38;2;245;224;220m' ;;
    flamingo)  C_ACCENT='\033[38;2;242;205;205m' ;;
    pink)      C_ACCENT='\033[38;2;245;194;231m' ;;
    mauve)     C_ACCENT="$C_MAUVE" ;;
    red)       C_ACCENT="$C_RED" ;;
    maroon)    C_ACCENT='\033[38;2;235;160;172m' ;;
    peach)     C_ACCENT="$C_PEACH" ;;
    yellow)    C_ACCENT="$C_YELLOW" ;;
    sky)       C_ACCENT='\033[38;2;137;220;235m' ;;
    sapphire)  C_ACCENT='\033[38;2;116;199;236m' ;;
    *)         C_ACCENT="$C_GRAY" ;;  # gray: all same color
esac

# Returns a Catppuccin color based on usage percentage threshold
usage_color_for_pct() {
    local pct=$1
    if [[ "$pct" -ge 90 ]]; then echo "$C_RED"
    elif [[ "$pct" -ge 70 ]]; then echo "$C_PEACH"
    elif [[ "$pct" -ge 50 ]]; then echo "$C_YELLOW"
    else echo "$C_GREEN"
    fi
}

# Extract model and cwd
model=$(echo "$input" | jq -r '.model.display_name // .model.id // "?"')
cwd=$(echo "$input" | jq -r '.cwd // empty')
dir=$(basename "$cwd" 2>/dev/null || echo "?")

# Git info with caching (5s TTL per working directory)
# Uses a fixed per-cwd cache filename so results persist across invocations.
GIT_CACHE_MAX_AGE=5
branch=""
sync_status=""
remote_url=""
is_git=false

if [[ -n "$cwd" ]]; then
    cwd_hash=$(cksum <<< "$cwd" | cut -d' ' -f1)
    GIT_CACHE_FILE="/tmp/statusline-git-${cwd_hash}"

    git_cache_is_stale=true
    if [[ -f "$GIT_CACHE_FILE" ]]; then
        git_cache_mtime=$(stat -f %m "$GIT_CACHE_FILE" 2>/dev/null || stat -c %Y "$GIT_CACHE_FILE" 2>/dev/null || echo 0)
        if [[ $(( $(date +%s) - git_cache_mtime )) -le $GIT_CACHE_MAX_AGE ]]; then
            git_cache_is_stale=false
        fi
    fi

    if [[ "$git_cache_is_stale" == true ]]; then
        if [[ -d "$cwd" ]] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            branch_val=$(git -C "$cwd" branch --show-current 2>/dev/null)
            sync_val=""
            remote_val=""

            if [[ -n "$branch_val" ]]; then
                # Check sync status with upstream
                # shellcheck disable=SC1083  # @{upstream} is valid git syntax
                upstream=$(git -C "$cwd" rev-parse --abbrev-ref @{upstream} 2>/dev/null || true)
                if [[ -n "$upstream" ]]; then
                    # Find most recent remote sync time (fetch or push)
                    # FETCH_HEAD is updated by fetch/pull; remote ref is updated by push
                    fetch_ago=""
                    latest_sync=0
                    fetch_head="$cwd/.git/FETCH_HEAD"
                    if [[ -f "$fetch_head" ]]; then
                        fmt=$(stat -f %m "$fetch_head" 2>/dev/null || stat -c %Y "$fetch_head" 2>/dev/null || echo 0)
                        [[ "$fmt" -gt "$latest_sync" ]] && latest_sync="$fmt"
                    fi
                    remote_ref="$cwd/.git/refs/remotes/origin/${branch_val}"
                    if [[ -f "$remote_ref" ]]; then
                        rmt=$(stat -f %m "$remote_ref" 2>/dev/null || stat -c %Y "$remote_ref" 2>/dev/null || echo 0)
                        [[ "$rmt" -gt "$latest_sync" ]] && latest_sync="$rmt"
                    fi
                    if [[ "$latest_sync" -gt 0 ]]; then
                        now=$(date +%s)
                        diff_t=$((now - latest_sync))
                        if [[ $diff_t -lt 60 ]]; then
                            fetch_ago="<1m ago"
                        elif [[ $diff_t -lt 3600 ]]; then
                            fetch_ago="$((diff_t / 60))m ago"
                        elif [[ $diff_t -lt 86400 ]]; then
                            fetch_ago="$((diff_t / 3600))h ago"
                        else
                            fetch_ago="$((diff_t / 86400))d ago"
                        fi
                    fi

                    # shellcheck disable=SC1083  # @{upstream} is valid git syntax
                    counts=$(git -C "$cwd" rev-list --left-right --count HEAD...@{upstream} 2>/dev/null || true)
                    ahead=$(echo "$counts" | cut -f1)
                    behind=$(echo "$counts" | cut -f2)
                    ahead=${ahead:-0}
                    behind=${behind:-0}
                    if [[ "$ahead" -eq 0 && "$behind" -eq 0 ]]; then
                        if [[ -n "$fetch_ago" ]]; then
                            sync_val="♻️ ${fetch_ago}"
                        else
                            sync_val="♻️"
                        fi
                    elif [[ "$ahead" -gt 0 && "$behind" -eq 0 ]]; then
                        sync_val="${ahead} ⬆️"
                    elif [[ "$ahead" -eq 0 && "$behind" -gt 0 ]]; then
                        sync_val="${behind} ⬇️"
                    else
                        sync_val="${ahead} ⬆️ ${behind} ⬇️"
                    fi
                else
                    sync_val="🚱"
                fi

                # Get remote URL for clickable link; convert SSH to HTTPS
                raw_remote=$(git -C "$cwd" remote get-url origin 2>/dev/null || true)
                if [[ -n "$raw_remote" ]]; then
                    remote_val=$(echo "$raw_remote" | sed 's|git@github\.com:|https://github.com/|' | sed 's|\.git$||')
                fi
            fi

            printf '%s\n' "1|${branch_val}|${sync_val}|${remote_val}" > "$GIT_CACHE_FILE"
        else
            printf '%s\n' "0|||" > "$GIT_CACHE_FILE"
        fi
    fi

    # Read cached values (pipe-delimited; last field captures remainder including empty remote_url)
    is_git_cached=""
    if [[ -f "$GIT_CACHE_FILE" ]]; then
        IFS='|' read -r is_git_cached branch sync_status remote_url < "$GIT_CACHE_FILE" || true
        [[ "$is_git_cached" == "1" ]] && is_git=true
    fi
fi

# Context window size and pre-calculated percentage (v2.1.50+: includes system prompt/tools/memory)
max_context=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
if [[ "$max_context" -ge 1000000 && $((max_context % 1000000)) -eq 0 ]]; then
    max_display="$((max_context / 1000000))M"
else
    max_display="$((max_context / 1000))k"
fi
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

bar_width=10

if [[ -n "$used_pct" ]]; then
    # Round float to integer
    pct=$(printf "%.0f" "$used_pct")
    pct_prefix=""
else
    # At conversation start, used_percentage is null — show baseline estimate
    # ~20k: system prompt (~3k), tools (~15k), memory (~300), framing (~2k)
    pct=$(( 20000 * 100 / max_context ))
    pct_prefix="~"
fi

[[ $pct -gt 100 ]] && pct=100

bar=""
for ((i=0; i<bar_width; i++)); do
    bar_start=$((i * 10))
    progress=$((pct - bar_start))
    if [[ $progress -ge 8 ]]; then
        bar+="${C_BAR[$i]}${BAR_FULL}${C_RESET}"
    elif [[ $progress -ge 3 ]]; then
        bar+="${C_BAR[$i]}${BAR_HALF}${C_RESET}"
    else
        bar+="${C_BAR_EMPTY}${BAR_EMPTY}${C_RESET}"
    fi
done

# Match % color to the tip of the bar (last colored segment in C_BAR gradient)
if [[ $pct -ge 3 ]]; then
    bar_tip_idx=$(( (pct - 3) / 10 ))
    [[ $bar_tip_idx -gt 9 ]] && bar_tip_idx=9
    ctx_col="${C_BAR[$bar_tip_idx]}"
else
    ctx_col="$C_GRAY"
fi
ctx="🪙 ${bar} ${C_GRAY} ${pct_prefix}${ctx_col}${pct}%${C_RESET} ⚡️ ${max_display}"

# ── Usage stats via Anthropic OAuth API ──────────────────────────────────────
get_oauth_creds() {
    local blob creds_file="$HOME/.claude/.credentials.json"
    if command -v security >/dev/null 2>&1; then
        blob=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null || true)
        if [[ -n "$blob" ]]; then
            echo "$blob"; return 0
        fi
    fi
    if [[ -f "$creds_file" ]]; then
        cat "$creds_file"; return 0
    fi
    echo ""
}

get_oauth_token() {
    local creds token
    creds=$(get_oauth_creds)
    [[ -z "$creds" ]] && { echo ""; return; }
    token=$(echo "$creds" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null || true)
    if [[ -n "$token" && "$token" != "null" ]]; then
        echo "$token"; return 0
    fi
    echo ""
}

get_subscription_type() {
    local creds sub_type
    creds=$(get_oauth_creds)
    [[ -z "$creds" ]] && { echo ""; return; }
    sub_type=$(echo "$creds" | jq -r '.claudeAiOauth.subscriptionType // empty' 2>/dev/null || true)
    echo "$sub_type"
}

build_usage_bar() {
    local pct=$1 width=10 bar="" bar_start progress
    [[ "$pct" -lt 0 ]] && pct=0
    [[ "$pct" -gt 100 ]] && pct=100
    for ((i=0; i<width; i++)); do
        bar_start=$(( i * 10 ))
        progress=$(( pct - bar_start ))
        if [[ $progress -ge 8 ]]; then
            bar+="${C_BAR[$i]}${BAR_FULL}${C_RESET}"
        elif [[ $progress -ge 3 ]]; then
            bar+="${C_BAR[$i]}${BAR_HALF}${C_RESET}"
        else
            bar+="${C_BAR_EMPTY}${BAR_EMPTY}${C_RESET}"
        fi
    done
    echo "$bar"
}

format_reset_time() {
    local iso="$1" style="$2" stripped epoch
    [[ -z "$iso" || "$iso" == "null" ]] && return
    stripped="${iso%%.*}"; stripped="${stripped%%Z}"
    epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null || date -d "$iso" +%s 2>/dev/null || true)
    [[ -z "$epoch" ]] && return
    if [[ "$style" == "time" ]]; then
        date -j -r "$epoch" +"%l%p" 2>/dev/null | sed 's/^ //; s/\.//g' | tr '[:upper:]' '[:lower:]' || \
        date -d "@$epoch" +"%l%P" 2>/dev/null | sed 's/^ //'
    else
        date -j -r "$epoch" +"%m-%e" 2>/dev/null | sed 's/^0//; s/ //' || \
        date -d "@$epoch" +"%m-%-d" 2>/dev/null | sed 's/^0//'
    fi
}

usage_line=""
usage_cache_file="/tmp/claude-statusline-usage.json"
usage_cache_max_age=150
usage_needs_refresh=true
usage_data=""

if [[ -f "$usage_cache_file" ]]; then
    usage_cache_mtime=$(stat -f %m "$usage_cache_file" 2>/dev/null || stat -c %Y "$usage_cache_file" 2>/dev/null || echo 0)
    usage_cache_age=$(( $(date +%s) - usage_cache_mtime ))
    if [[ "$usage_cache_age" -lt "$usage_cache_max_age" ]]; then
        usage_needs_refresh=false
        usage_data=$(cat "$usage_cache_file" 2>/dev/null)
    fi
fi

subscription_type=$(get_subscription_type)

if [[ "$usage_needs_refresh" == true ]]; then
    token=$(get_oauth_token)
    if [[ -n "$token" ]]; then
        response=$(curl -s --max-time 5 \
            -H "Accept: application/json" \
            -H "Authorization: Bearer $token" \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "User-Agent: claude-code/2.1.34" \
            "https://api.anthropic.com/api/oauth/usage" 2>/dev/null || true)
        # Cache if response is valid JSON (works for both pro and enterprise)
        if echo "$response" | jq -e . >/dev/null 2>&1; then
            usage_data="$response"
            echo "$response" > "$usage_cache_file"
        fi
    fi
    [[ -z "$usage_data" && -f "$usage_cache_file" ]] && usage_data=$(cat "$usage_cache_file" 2>/dev/null)
fi

if [[ -n "$usage_data" ]] && echo "$usage_data" | jq -e . >/dev/null 2>&1; then
    if [[ "$subscription_type" == "enterprise" ]]; then
        # Enterprise: show extra_usage (monthly credits) if available
        if echo "$usage_data" | jq -e '.extra_usage' >/dev/null 2>&1; then
            eu_pct=$(echo "$usage_data" | jq -r '.extra_usage.utilization // 0' | awk '{printf "%.0f", $1}')
            eu_used=$(echo "$usage_data" | jq -r '.extra_usage.used_credits // 0' | awk '{printf "%.0f", $1}')
            eu_limit=$(echo "$usage_data" | jq -r '.extra_usage.monthly_limit // 0' | awk '{printf "%.0f", $1}')
            eu_bar=$(build_usage_bar "$eu_pct")
            eu_tip=$(( eu_pct >= 3 ? (eu_pct - 3) / 10 : 0 )); [[ $eu_tip -gt 9 ]] && eu_tip=9
            eu_col="${C_BAR[$eu_tip]}"

            eu_limit_k=$(awk "BEGIN {printf \"%.0f\", $eu_limit / 1000}")
            usage_line="🏢 ${eu_bar}  ${eu_col}${eu_pct}%${C_RESET} ${C_GRAY}(${eu_used}/${eu_limit_k}k credits)${C_RESET}"
        fi
    else
        # Pro/individual: show 5hr and 7day usage
        if echo "$usage_data" | jq -e '.five_hour' >/dev/null 2>&1; then
            fh_pct=$(echo "$usage_data" | jq -r '.five_hour.utilization // 0' | awk '{printf "%.0f", $1}')
            fh_reset=$(format_reset_time "$(echo "$usage_data" | jq -r '.five_hour.resets_at // empty')" "time")
            fh_bar=$(build_usage_bar "$fh_pct")
            fh_tip=$(( fh_pct >= 3 ? (fh_pct - 3) / 10 : 0 )); [[ $fh_tip -gt 9 ]] && fh_tip=9
            fh_col="${C_BAR[$fh_tip]}"

            sd_pct=$(echo "$usage_data" | jq -r '.seven_day.utilization // 0' | awk '{printf "%.0f", $1}')
            sd_resets_at=$(echo "$usage_data" | jq -r '.seven_day.resets_at // empty')
            sd_reset_date=$(format_reset_time "$sd_resets_at" "date")
            today_date=$(date +"%m-%e" | sed 's/^0//; s/ //')
            if [[ -n "$sd_reset_date" && "$sd_reset_date" == "$today_date" ]]; then
                sd_reset_time=$(format_reset_time "$sd_resets_at" "time")
                sd_reset="${sd_reset_time} today"
            else
                sd_reset="$sd_reset_date"
            fi
            sd_bar=$(build_usage_bar "$sd_pct")
            sd_tip=$(( sd_pct >= 3 ? (sd_pct - 3) / 10 : 0 )); [[ $sd_tip -gt 9 ]] && sd_tip=9
            sd_col="${C_BAR[$sd_tip]}"

            fh_reset_fmt="${fh_reset:+ ${C_GRAY}🔄 ${fh_reset}}"
            sd_reset_fmt="${sd_reset:+ ${C_GRAY}🔄 ${sd_reset}}"

            usage_line="⏱️ ${fh_bar}  ${fh_col}${fh_pct}%${C_RESET}${fh_reset_fmt}${C_RESET}"
            usage_line+=" / 🗓️ ${sd_bar}  ${sd_col}${sd_pct}%${C_RESET}${sd_reset_fmt}${C_RESET}"
        fi
    fi
fi

# Clickable links via OSC 8: \033]8;;URL\aTEXT\033]8;;\a
# Cmd+click (macOS) or Ctrl+click (Linux) to open. Requires iTerm2/Kitty/WezTerm.
dir_display="${dir}"
if [[ -n "$cwd" ]]; then
    dir_display="\033]8;;file://${cwd}\a${dir}\033]8;;\a"
fi

branch_display="${branch}"
if [[ -n "$branch" && -n "$remote_url" ]]; then
    branch_display="\033]8;;${remote_url}/tree/${branch}\a${branch}\033]8;;\a"
fi

# Line 1: Directory and git info
line1="${C_GRAY}📦 ${dir_display}"
if [[ -n "$branch" ]]; then
    git_status_str=""
    [[ -n "$sync_status" ]] && git_status_str=" (${sync_status})"
    line1+=" / 🌿 ${branch_display}${git_status_str}"
elif [[ "$is_git" == false ]]; then
    line1+=" / ⛔️"
fi
line1+="${C_RESET}"

# Line 2: Model and context usage
line2="🧿 ${C_ACCENT}${model}${C_GRAY} / ${ctx}${C_RESET}"

printf '%b\n' "$line1"
printf '%b\n' "$line2"
[[ -n "$usage_line" ]] && printf '%b\n' "$usage_line"
