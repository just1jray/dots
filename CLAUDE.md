### Shell Script Standards

- Use `set -euo pipefail` for strict error handling
- Target both bash and zsh compatibility where appropriate

## Theme & Styling

- Always use Catppuccin Mocha theme and colors 

## Git Workflow

- Never commit directly to `main` — always create a branch first
- Branch names: `feat/`, `fix/`, `chore/`, or `docs/` prefix plus a short kebab-case description
- Every change lands via a pull request, even solo work
- Use the `gh` CLI to create and manage PRs
- Keep unrelated working-tree changes out of a commit; stage only files relevant to the task
