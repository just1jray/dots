# Global Claude Code Settings

- For GitHub URLs, use gh CLI instead of web scraping

## Development Tool Standards

### Python Development

**Version Management (pyenv):**
- pyenv is available for managing Python versions
- Check available versions: `pyenv versions`
- Set local version for project: `pyenv local <version>`
- Install new version: `pyenv install <version>`

**Virtual Environments (required):**
- **Always use virtual environments** - Never run Python commands directly in the system environment
- Create a venv if one doesn't exist: `python3 -m venv venv`
- Activate before any Python operations: `source venv/bin/activate`
- Install packages only within activated venv: `pip install <package>`
- Deactivate when done: `deactivate`

### Shell / Environment

- `cd` is aliased to zoxide (`__zoxide_z`) — use `builtin cd` or absolute paths in Bash tool calls, since Claude Code runs non-interactive shells that don't source `.zshrc`
- Bun is at `~/.bun/bin/bun`

### Node.js Development

- **Prefer Bun over npm/npx** - Bun is available and faster for most JavaScript tasks
  - Run scripts: `bun run <script>`
  - Install packages: `bun install` or `bun add <package>`
  - Execute packages: `bunx <package>` (instead of npx)
  - Run TypeScript directly: `bun <file.ts>`

- **Node version management** - nvm is available for managing Node.js versions
  - Check available versions: `nvm list`
  - Use specific version: `nvm use <version>`
  - Install new version: `nvm install <version>`
  - Set default version: `nvm alias default <version>`
