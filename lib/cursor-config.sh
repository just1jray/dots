#!/usr/bin/env bash

# Merge portable Cursor CLI preferences without replacing machine-local state.
# The tracked permissions key is always ignored so interactive allowlists stay local.
merge_cursor_cli_config() {
    local source_file=$1
    local target_file=$2
    local dry_run=$3
    local target_dir merged

    target_dir=$(dirname "$target_file")

    if [ ! -f "$source_file" ]; then
        log_warning "Cursor CLI config not found: $source_file"
        return 0
    fi

    if ! command_exists jq; then
        log_warning "jq not found. Skipping Cursor CLI config merge (install jq to apply cursor/cli-config.json)."
        return 0
    fi

    if [ -L "$target_file" ]; then
        log_error "Refusing to merge Cursor CLI config into a symlink: $target_file"
        return 1
    fi

    if [ "$dry_run" = true ]; then
        if [ -e "$target_file" ]; then
            log_info "Would merge Cursor CLI preferences into $target_file (tracked keys win; auth, cache, and permissions preserved)"
        else
            log_info "Would create $target_file from $source_file"
        fi
        return 0
    fi

    if ! mkdir -p "$target_dir"; then
        log_error "Failed to create Cursor CLI config directory: $target_dir"
        return 1
    fi

    if ! merged=$(mktemp "$target_dir/.cli-config.json.tmp.XXXXXX"); then
        log_error "Failed to create a temporary Cursor CLI config in $target_dir"
        return 1
    fi

    if [ -e "$target_file" ]; then
        if ! jq -s '.[0] + (.[1] | del(.permissions))' \
            "$target_file" "$source_file" >"$merged"; then
            log_error "Failed to merge Cursor CLI config with jq"
            rm -f "$merged"
            return 1
        fi
    elif ! jq 'del(.permissions)' "$source_file" >"$merged"; then
        log_error "Failed to read Cursor CLI config with jq"
        rm -f "$merged"
        return 1
    fi

    if ! mv "$merged" "$target_file"; then
        log_error "Failed to write Cursor CLI config: $target_file"
        rm -f "$merged"
        return 1
    fi

    log_success "Merged Cursor CLI preferences into $target_file"
}
