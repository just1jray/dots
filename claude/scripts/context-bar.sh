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

# Extract model, directory, and cwd
model=$(echo "$input" | jq -r '.model.display_name // .model.id // "?"')
cwd=$(echo "$input" | jq -r '.cwd // empty')
dir=$(basename "$cwd" 2>/dev/null || echo "?")

# Get git branch, uncommitted file count, and sync status
branch=""
git_status=""
is_git=false
if [[ -n "$cwd" && -d "$cwd" ]] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    is_git=true
    branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
    if [[ -n "$branch" ]]; then
        # Check sync status with upstream
        sync_status=""
        # shellcheck disable=SC1083  # @{upstream} is valid git syntax
        upstream=$(git -C "$cwd" rev-parse --abbrev-ref @{upstream} 2>/dev/null || true)
        if [[ -n "$upstream" ]]; then
            # Get last fetch time
            fetch_head="$cwd/.git/FETCH_HEAD"
            fetch_ago=""
            if [[ -f "$fetch_head" ]]; then
                fetch_time=$(stat -f %m "$fetch_head" 2>/dev/null || stat -c %Y "$fetch_head" 2>/dev/null)
                if [[ -n "$fetch_time" ]]; then
                    now=$(date +%s)
                    diff=$((now - fetch_time))
                    if [[ $diff -lt 60 ]]; then
                        fetch_ago="<1m ago"
                    elif [[ $diff -lt 3600 ]]; then
                        fetch_ago="$((diff / 60))m ago"
                    elif [[ $diff -lt 86400 ]]; then
                        fetch_ago="$((diff / 3600))h ago"
                    else
                        fetch_ago="$((diff / 86400))d ago"
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
                    sync_status="♻️ ${fetch_ago}"
                else
                    sync_status="♻️"
                fi
            elif [[ "$ahead" -gt 0 && "$behind" -eq 0 ]]; then
                sync_status="${ahead} ⬆️"
            elif [[ "$ahead" -eq 0 && "$behind" -gt 0 ]]; then
                sync_status="${behind} ⬇️"
            else
                sync_status="${ahead} ⬆️ ${behind} ⬇️"
            fi
        else
            sync_status="🚱"
        fi

        git_status="(${sync_status})"
    fi
fi

# Get transcript path for context calculation and last message feature
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

# Get context window size from JSON (accurate), but calculate tokens from transcript
# (more accurate than total_input_tokens which excludes system prompt/tools/memory)
# See: github.com/anthropics/claude-code/issues/13652
max_context=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
max_k=$((max_context / 1000))

# Calculate context bar from transcript
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    context_length=$(jq -s '
        map(select(.message.usage and .isSidechain != true and .isApiErrorMessage != true)) |
        last |
        if . then
            (.message.usage.input_tokens // 0) +
            (.message.usage.cache_read_input_tokens // 0) +
            (.message.usage.cache_creation_input_tokens // 0)
        else 0 end
    ' < "$transcript_path" 2>/dev/null || echo 0)

    # 20k baseline: includes system prompt (~3k), tools (~15k), memory (~300),
    # plus ~2k for git status, env block, XML framing, and other dynamic context
    baseline=20000
    bar_width=10

    if [[ "$context_length" -gt 0 ]]; then
        pct=$((context_length * 100 / max_context))
        pct_prefix=""
    else
        # At conversation start, ~20k baseline is already loaded
        pct=$((baseline * 100 / max_context))
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
else
    # Transcript not available yet - show baseline estimate
    baseline=20000
    bar_width=10
    pct=$((baseline * 100 / max_context))
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

    ctx="${bar} ${C_GRAY} ~${pct}% ⚡️ ${max_k}k 🪙"
fi

# Build output: Model | Dir | Branch (uncommitted) | Context
output="🧿 ${C_ACCENT}${model}${C_GRAY} / 📦 ${dir}"
if [[ -n "$branch" ]]; then
    output+=" / 🌿 ${branch} ${git_status}"
elif [[ "$is_git" == false ]]; then
    output+=" / ⛔️"
fi
output+=" / ${ctx}${C_RESET}"

printf '%b\n' "$output"
