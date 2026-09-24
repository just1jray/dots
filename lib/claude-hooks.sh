# Merge portable hook stanzas into ~/.claude/settings.json.
# Sourced by setup.sh and update.sh, which provide log_*, command_exists
# and DRY_RUN.
#
# settings.json stays machine-local (it holds model, statusLine, plugins and
# other per-machine choices), so the hook wiring cannot simply be symlinked.
# Instead the stanzas live in claude/settings.hooks.json, with
# {{CLAUDE_HOOKS}} standing for the installed hooks directory.
#
# A hook is managed when its command runs a script from the hooks directory.
# Managed hooks are keyed on the script basename, so quoted and unquoted
# forms of one command match, and are replaced on every merge so timeout and
# matcher changes propagate. Every other entry is left as it is. The merge is
# idempotent for any event type.

# $dir is the hooks directory, $frag the slurped fragment; input is settings.
# shellcheck disable=SC2016
_CLAUDE_HOOKS_JQ='
def managed_name:
  if type == "object" and (.command | type) == "string" then
    [.command | split("\"") | join("") | split("'"'"'") | join("")
     | splits("\\s+")
     | select(startswith($dir + "/") or test("/\\.claude/hooks/[^/]+$"))]
    | if length > 0 then (last | split("/") | last) else null end
  else null end;

($frag[0].hooks
 | walk(if type == "string" then split("{{CLAUDE_HOOKS}}") | join($dir) else . end)
) as $add
| .hooks = (.hooks // {})
| reduce ($add | to_entries[]) as $evt (.;
    [$evt.value[].hooks[]? | managed_name | select(. != null)] as $names
    | .hooks[$evt.key] = (
        [ (.hooks[$evt.key] // [])[]
          | if type == "object" and (.hooks | type) == "array" and (.hooks | length) > 0 then
              .hooks |= map(select(managed_name as $n
                                   | $n == null or (($n | IN($names[])) | not)))
              | select((.hooks | length) > 0)
            else . end ]
        + $evt.value))
'

# $1 fragment, $2 settings.json, $3 installed hooks directory.
# Returns 1 when the merge could not be done; settings.json is then untouched.
merge_claude_hooks() {
    local fragment="$1"
    local settings="$2"
    local hooks_dir="$3"
    local merged backup

    [ -f "$fragment" ] || return 0

    if ! command_exists jq; then
        log_warning "jq not found; skipping Claude hook merge (hooks are installed but not registered)"
        return 0
    fi

    if ! jq -e '.hooks | type == "object"' "$fragment" >/dev/null 2>&1; then
        log_warning "$fragment has no valid hooks object; skipping hook merge"
        return 1
    fi

    if [ -e "$settings" ] && ! jq -e 'type == "object"' "$settings" >/dev/null 2>&1; then
        log_warning "$settings is not valid JSON; skipping hook merge"
        return 1
    fi

    if [ "${DRY_RUN:-false}" = true ]; then
        log_info "Would merge hook config from $fragment into $settings"
        return 0
    fi

    if ! merged=$(mktemp); then
        log_warning "Could not create a temporary file; skipping hook merge"
        return 1
    fi

    if [ -e "$settings" ]; then
        jq --arg dir "$hooks_dir" --slurpfile frag "$fragment" "$_CLAUDE_HOOKS_JQ" \
            "$settings" >"$merged" 2>/dev/null
    else
        echo '{}' | jq --arg dir "$hooks_dir" --slurpfile frag "$fragment" "$_CLAUDE_HOOKS_JQ" \
            >"$merged" 2>/dev/null
    fi || {
        log_warning "Failed to merge hook config into $settings"
        rm -f "$merged"
        return 1
    }

    if [ ! -s "$merged" ]; then
        log_warning "Hook merge produced no output; leaving $settings unchanged"
        rm -f "$merged"
        return 1
    fi

    if [ -e "$settings" ] && cmp -s "$settings" "$merged"; then
        log_info "Claude hook config already up to date in $settings"
        rm -f "$merged"
        return 0
    fi

    if [ -e "$settings" ]; then
        backup="${settings}.old_$(date +%F_%H-%M-%S)"
        if ! cp -p "$settings" "$backup"; then
            log_warning "Could not back up $settings; skipping hook merge"
            rm -f "$merged"
            return 1
        fi
        log_info "Backed up $settings → $backup"
    fi

    # Write in place so the file keeps its permissions (and any symlink).
    if ! cat "$merged" >"$settings"; then
        log_warning "Could not write $settings"
        rm -f "$merged"
        return 1
    fi
    rm -f "$merged"
    log_success "Merged Claude hook config into $settings"
}
