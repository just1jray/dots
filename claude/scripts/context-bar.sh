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
C_GRAY='\033[38;5;245m'  # explicit gray for default text
C_BAR_EMPTY='\033[38;5;238m'
BAR_FULL='▰'
BAR_HALF='▰'
BAR_EMPTY='▱'

# Context bar gradient: green → yellow → peach → red → mauve (Catppuccin Mocha)
C_BAR=(
    '\033[38;2;166;227;161m'  # green
    '\033[38;2;207;226;168m'  # green-yellow
    '\033[38;2;249;226;175m'  # yellow
    '\033[38;2;249;202;155m'  # yellow-peach
    '\033[38;2;250;179;135m'  # peach
    '\033[38;2;247;166;146m'  # peach-red
    '\033[38;2;245;152;157m'  # light red
    '\033[38;2;243;139;168m'  # red
    '\033[38;2;223;152;207m'  # red-mauve
    '\033[38;2;203;166;247m'  # mauve
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
    mauve)     C_ACCENT='\033[38;2;203;166;247m' ;;
    red)       C_ACCENT='\033[38;2;243;139;168m' ;;
    maroon)    C_ACCENT='\033[38;2;235;160;172m' ;;
    peach)     C_ACCENT='\033[38;2;250;179;135m' ;;
    yellow)    C_ACCENT='\033[38;2;249;226;175m' ;;
    sky)       C_ACCENT='\033[38;2;137;220;235m' ;;
    sapphire)  C_ACCENT='\033[38;2;116;199;236m' ;;
    *)         C_ACCENT="$C_GRAY" ;;  # gray: all same color
esac

# Extract model and cwd
model=$(echo "$input" | jq -r '.model.display_name // .model.id // "?"')
cwd=$(echo "$input" | jq -r '.cwd // empty')
dir=$(basename "$cwd" 2>/dev/null || echo "?")

# Git info with caching (5s TTL per working directory)
# Uses a fixed per-cwd cache filename so results persist across invocations.
CACHE_MAX_AGE=5
branch=""
sync_status=""
remote_url=""
is_git=false

if [[ -n "$cwd" ]]; then
    cwd_hash=$(cksum <<< "$cwd" | cut -d' ' -f1)
    CACHE_FILE="/tmp/statusline-git-${cwd_hash}"

    cache_is_stale=true
    if [[ -f "$CACHE_FILE" ]]; then
        cache_mtime=$(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
        if [[ $(( $(date +%s) - cache_mtime )) -le $CACHE_MAX_AGE ]]; then
            cache_is_stale=false
        fi
    fi

    if [[ "$cache_is_stale" == true ]]; then
        if [[ -d "$cwd" ]] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            branch_val=$(git -C "$cwd" branch --show-current 2>/dev/null)
            sync_val=""
            remote_val=""

            if [[ -n "$branch_val" ]]; then
                # Check sync status with upstream
                # shellcheck disable=SC1083  # @{upstream} is valid git syntax
                upstream=$(git -C "$cwd" rev-parse --abbrev-ref @{upstream} 2>/dev/null || true)
                if [[ -n "$upstream" ]]; then
                    fetch_head="$cwd/.git/FETCH_HEAD"
                    fetch_ago=""
                    if [[ -f "$fetch_head" ]]; then
                        fetch_mtime=$(stat -f %m "$fetch_head" 2>/dev/null || stat -c %Y "$fetch_head" 2>/dev/null)
                        if [[ -n "$fetch_mtime" ]]; then
                            now=$(date +%s)
                            diff_t=$((now - fetch_mtime))
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

            printf '%s\n' "1|${branch_val}|${sync_val}|${remote_val}" > "$CACHE_FILE"
        else
            printf '%s\n' "0|||" > "$CACHE_FILE"
        fi
    fi

    # Read cached values (pipe-delimited; last field captures remainder including empty remote_url)
    is_git_cached=""
    if [[ -f "$CACHE_FILE" ]]; then
        IFS='|' read -r is_git_cached branch sync_status remote_url < "$CACHE_FILE" || true
        [[ "$is_git_cached" == "1" ]] && is_git=true
    fi
fi

# Context window size and pre-calculated percentage (v2.1.50+: includes system prompt/tools/memory)
max_context=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
max_k=$((max_context / 1000))
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

ctx="${bar} ${C_GRAY} ${pct_prefix}${pct}% ⚡️ ${max_k}k 🪙"

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

# Line 1: Model and context usage
line1="🧿 ${C_ACCENT}${model}${C_GRAY} / ${ctx}${C_RESET}"

# Line 2: Directory and git info
line2="${C_GRAY}📦 ${dir_display}"
if [[ -n "$branch" ]]; then
    git_status_str=""
    [[ -n "$sync_status" ]] && git_status_str=" (${sync_status})"
    line2+=" / 🌿 ${branch_display}${git_status_str}"
elif [[ "$is_git" == false ]]; then
    line2+=" / ⛔️"
fi
line2+="${C_RESET}"

printf '%b\n' "$line1"
printf '%b\n' "$line2"
