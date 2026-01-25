### Shell Script Standards

- Use `set -euo pipefail` for strict error handling
- Follow shellcheck rules configured in `.shellcheckrc`
- Target both bash and zsh compatibility where appropriate
- See `.shellcheckrc` for disabled warnings (SC1090, SC1091, SC2148, SC2312)
- Always make sure shellcheck is passing when finished

## Theme & Styling

- Always use Catppuccin Mocha theme and colors 
