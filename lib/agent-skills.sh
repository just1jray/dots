# Install skills from the agent-skills repo into every coding agent.
# Sourced by setup.sh and update.sh, which provide log_* and DRY_RUN.
#
# Skills live in their own private repo (just1jray/agent-skills), shared by
# Claude Code, Codex, Gemini, Cursor, Copilot and OpenCode. Its install.sh
# symlinks each skill into every installed agent's skills directory.
#
# Never fails the caller: a host without access to the private repo just
# goes without skills, with a warning.

AGENT_SKILLS_REPO="${AGENT_SKILLS_REPO:-git@github.com:just1jray/agent-skills.git}"
AGENT_SKILLS_DIR="${AGENT_SKILLS_DIR:-$HOME/Developer/src/agent-skills}"

# $1 = "pull" to fast-forward an existing clone first.
sync_agent_skills() {
    local mode="${1:-}"
    local installer="$AGENT_SKILLS_DIR/scripts/install.sh"

    if [ ! -d "$AGENT_SKILLS_DIR/.git" ]; then
        if [ "${DRY_RUN:-false}" = true ]; then
            log_info "Would clone agent skills: $AGENT_SKILLS_REPO → $AGENT_SKILLS_DIR"
            return 0
        fi
        if ! git clone -q "$AGENT_SKILLS_REPO" "$AGENT_SKILLS_DIR"; then
            log_warning "Could not clone $AGENT_SKILLS_REPO; skipping agent skills"
            return 0
        fi
    elif [ "$mode" = pull ] && [ "${DRY_RUN:-false}" != true ]; then
        if ! git -C "$AGENT_SKILLS_DIR" pull -q --ff-only; then
            log_warning "Could not fast-forward $AGENT_SKILLS_DIR; installing its current checkout"
        fi
    fi

    if [ ! -f "$installer" ]; then
        log_warning "No installer at $installer; skipping agent skills"
        return 0
    fi

    if [ "${DRY_RUN:-false}" = true ]; then
        bash "$installer" --dry-run || log_warning "Agent skills dry run failed"
    else
        bash "$installer" || log_warning "Agent skills install failed"
    fi
    return 0
}
