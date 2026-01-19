#!/usr/bin/env bats
# Tests for setup.sh

# Get the absolute path to the project root
PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    load 'bats/bats-support/load'
    load 'bats/bats-assert/load'
    load 'helpers/common.bash'
    load 'helpers/setup-functions.bash'

    setup_temp_dir
    setup_home_structure
}

teardown() {
    teardown_temp_dir
}

# =============================================================================
# command_exists() tests
# =============================================================================

@test "command_exists: returns 0 for existing command (bash)" {
    run command_exists bash
    assert_success
}

@test "command_exists: returns 0 for existing command (ls)" {
    run command_exists ls
    assert_success
}

@test "command_exists: returns 1 for non-existing command" {
    run command_exists this_command_does_not_exist_12345
    assert_failure
}

@test "command_exists: returns 1 for empty string" {
    run command_exists ""
    assert_failure
}

# =============================================================================
# print_usage() tests
# =============================================================================

@test "print_usage: shows Usage header" {
    run print_usage
    assert_success
    assert_output --partial "Usage:"
}

@test "print_usage: shows help option" {
    run print_usage
    assert_success
    assert_output --partial "-h, --help"
}

@test "print_usage: shows force option" {
    run print_usage
    assert_success
    assert_output --partial "-f, --force"
}

@test "print_usage: shows dry-run option" {
    run print_usage
    assert_success
    assert_output --partial "-n, --dry-run"
}

@test "print_usage: shows skip-plugins option" {
    run print_usage
    assert_success
    assert_output --partial "-s, --skip-plugins"
}

@test "print_usage: shows check-nvchad option" {
    run print_usage
    assert_success
    assert_output --partial "-c, --check-nvchad"
}

@test "print_usage: shows install-font option" {
    run print_usage
    assert_success
    assert_output --partial "-i, --install-font"
}

# =============================================================================
# create_directories() tests
# =============================================================================

@test "create_directories: creates ZSH plugins directory" {
    run create_directories
    assert_success
    [ -d "$ZSH_PLUGINS_DIR" ]
}

@test "create_directories: creates Developer/src directory" {
    run create_directories
    assert_success
    [ -d "$DEV_DIR" ]
}

@test "create_directories: creates tmux plugins directory" {
    run create_directories
    assert_success
    [ -d "$TMUX_PLUGINS_DIR" ]
}

@test "create_directories: creates tmux resurrect directory" {
    run create_directories
    assert_success
    [ -d "$TMUX_PLUGIN_RESURRECT_DIR" ]
}

@test "create_directories: reports existing directories" {
    mkdir -p "$ZSH_PLUGINS_DIR"
    run create_directories
    assert_success
    assert_output --partial "Directory already exists: $ZSH_PLUGINS_DIR"
}

@test "create_directories: dry-run mode does not create directories" {
    DRY_RUN=true
    rmdir "$ZSH_PLUGINS_DIR" 2>/dev/null || true
    rmdir "$(dirname "$ZSH_PLUGINS_DIR")" 2>/dev/null || true
    run create_directories
    assert_success
    assert_output --partial "Would create directory"
    [ ! -d "$ZSH_PLUGINS_DIR" ]
}

# =============================================================================
# backup_config_file() tests
# =============================================================================

@test "backup_config_file: backs up existing file" {
    local test_file="$TEST_TEMP_DIR/test_config"
    echo "original content" > "$test_file"

    run backup_config_file "$test_file"
    assert_success

    # Original file should be gone
    [ ! -f "$test_file" ]

    # Backup file should exist
    local backup_count
    backup_count=$(ls "$TEST_TEMP_DIR"/test_config.old_* 2>/dev/null | wc -l)
    [ "$backup_count" -eq 1 ]
}

@test "backup_config_file: backs up existing directory" {
    local test_dir="$TEST_TEMP_DIR/test_dir"
    mkdir -p "$test_dir"
    echo "content" > "$test_dir/file.txt"

    run backup_config_file "$test_dir"
    assert_success

    # Original directory should be gone
    [ ! -d "$test_dir" ]

    # Backup directory should exist
    local backup_count
    backup_count=$(ls -d "$TEST_TEMP_DIR"/test_dir.backup_* 2>/dev/null | wc -l)
    [ "$backup_count" -eq 1 ]
}

@test "backup_config_file: removes symlink without backup" {
    local test_link="$TEST_TEMP_DIR/test_link"
    local target="$TEST_TEMP_DIR/target"
    echo "target content" > "$target"
    ln -s "$target" "$test_link"

    run backup_config_file "$test_link"
    assert_success

    # Symlink should be removed
    [ ! -L "$test_link" ]

    # Target should still exist
    [ -f "$target" ]
}

@test "backup_config_file: force flag removes file without backup" {
    FORCE=true
    local test_file="$TEST_TEMP_DIR/test_config"
    echo "original content" > "$test_file"

    run backup_config_file "$test_file"
    assert_success

    # Original file should be gone
    [ ! -f "$test_file" ]

    # No backup file should exist
    local backup_count
    backup_count=$(ls "$TEST_TEMP_DIR"/test_config.old_* 2>/dev/null | wc -l)
    [ "$backup_count" -eq 0 ]
    FORCE=false
}

@test "backup_config_file: force flag removes directory without backup" {
    FORCE=true
    local test_dir="$TEST_TEMP_DIR/test_dir"
    mkdir -p "$test_dir"
    echo "content" > "$test_dir/file.txt"

    run backup_config_file "$test_dir"
    assert_success

    # Original directory should be gone
    [ ! -d "$test_dir" ]

    # No backup directory should exist
    local backup_count
    backup_count=$(ls -d "$TEST_TEMP_DIR"/test_dir.backup_* 2>/dev/null | wc -l)
    [ "$backup_count" -eq 0 ]
    FORCE=false
}

@test "backup_config_file: dry-run mode does not modify file" {
    DRY_RUN=true
    local test_file="$TEST_TEMP_DIR/test_config"
    echo "original content" > "$test_file"

    run backup_config_file "$test_file"
    assert_success
    assert_output --partial "Would backup file"

    # Original file should still exist
    [ -f "$test_file" ]
    DRY_RUN=false
}

@test "backup_config_file: dry-run mode does not modify directory" {
    DRY_RUN=true
    local test_dir="$TEST_TEMP_DIR/test_dir"
    mkdir -p "$test_dir"

    run backup_config_file "$test_dir"
    assert_success
    assert_output --partial "Would backup directory"

    # Original directory should still exist
    [ -d "$test_dir" ]
    DRY_RUN=false
}

@test "backup_config_file: dry-run with force shows would remove message" {
    DRY_RUN=true
    FORCE=true
    local test_file="$TEST_TEMP_DIR/test_config"
    echo "original content" > "$test_file"

    run backup_config_file "$test_file"
    assert_success
    assert_output --partial "Would remove existing file without backup"

    # Original file should still exist
    [ -f "$test_file" ]
    DRY_RUN=false
    FORCE=false
}

@test "backup_config_file: handles non-existent file gracefully" {
    local test_file="$TEST_TEMP_DIR/nonexistent_file"

    run backup_config_file "$test_file"
    assert_success
}

# =============================================================================
# Argument parsing tests
# =============================================================================

@test "parse_args: sets FORCE=true with -f flag" {
    parse_args -f
    [ "$FORCE" = true ]
}

@test "parse_args: sets FORCE=true with --force flag" {
    parse_args --force
    [ "$FORCE" = true ]
}

@test "parse_args: sets DRY_RUN=true with -n flag" {
    parse_args -n
    [ "$DRY_RUN" = true ]
}

@test "parse_args: sets DRY_RUN=true with --dry-run flag" {
    parse_args --dry-run
    [ "$DRY_RUN" = true ]
}

@test "parse_args: sets SKIP_PLUGINS=true with -s flag" {
    parse_args -s
    [ "$SKIP_PLUGINS" = true ]
}

@test "parse_args: sets SKIP_PLUGINS=true with --skip-plugins flag" {
    parse_args --skip-plugins
    [ "$SKIP_PLUGINS" = true ]
}

@test "parse_args: sets CHECK_NVCHAD_ONLY=true with -c flag" {
    parse_args -c
    [ "$CHECK_NVCHAD_ONLY" = true ]
}

@test "parse_args: sets CHECK_NVCHAD_ONLY=true with --check-nvchad flag" {
    parse_args --check-nvchad
    [ "$CHECK_NVCHAD_ONLY" = true ]
}

@test "parse_args: sets INSTALL_FONT=true with -i flag" {
    parse_args -i
    [ "$INSTALL_FONT" = true ]
}

@test "parse_args: sets INSTALL_FONT=true with --install-font flag" {
    parse_args --install-font
    [ "$INSTALL_FONT" = true ]
}

@test "parse_args: handles multiple flags" {
    parse_args -f -n -s
    [ "$FORCE" = true ]
    [ "$DRY_RUN" = true ]
    [ "$SKIP_PLUGINS" = true ]
}

@test "parse_args: -h flag shows usage" {
    run parse_args -h
    assert_success
    assert_output --partial "Usage:"
}

@test "parse_args: --help flag shows usage" {
    run parse_args --help
    assert_success
    assert_output --partial "Usage:"
}

@test "parse_args: unknown flag returns error" {
    run parse_args --unknown-flag
    assert_failure
    assert_output --partial "Unknown option"
}

@test "parse_args: resets flags between calls" {
    parse_args -f
    [ "$FORCE" = true ]

    parse_args
    [ "$FORCE" = false ]
}
