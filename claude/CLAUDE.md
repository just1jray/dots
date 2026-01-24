# Global Claude Code Settings

This file provides global guidance to Claude Code across all projects.

## Development Tool Standards

### Python Development

- **Always use virtual environments** - Never run Python commands directly in the system environment
- **Python version management** - pyenv is available for managing Python versions
  - Check available versions: `pyenv versions`
  - Set local version: `pyenv local <version>`
  - Install new version: `pyenv install <version>`
- Create a venv if one doesn't exist: `python3 -m venv venv`
- Activate before any Python operations: `source venv/bin/activate`
- Install packages only within activated venv: `pip install <package>`
- Deactivate when done: `deactivate`

### Node.js Development

- **Node version management** - nvm is available for managing Node.js versions
  - Check available versions: `nvm list`
  - Use specific version: `nvm use <version>`
  - Install new version: `nvm install <version>`
  - Set default version: `nvm alias default <version>`
