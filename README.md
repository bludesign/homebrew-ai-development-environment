# AI Development Environment Homebrew Tap

## Install

This repository does not use Homebrew's `homebrew-` repository prefix, so add the tap with its explicit remote:

```bash
brew tap bludesign/ai-development-environment-tap \
  https://github.com/bludesign/ai-development-environment-tap.git
brew install ai-development-environment
```

## Service

Start the application as a keep-alive service:

```bash
brew services start ai-development-environment
```

By default it listens at `http://127.0.0.1:3090`. Persistent settings are stored in:

```text
$(brew --prefix)/etc/ai-development-environment.env
```

Edit `HOSTNAME` or `PORT`, then apply the changes:

```bash
brew services restart ai-development-environment
```

For a one-off foreground process, exported values override the configuration file:

```bash
HOSTNAME=0.0.0.0 PORT=8080 ai-development-environment
```

Service output is written to `$(brew --prefix)/var/log/ai-development-environment.log` and `$(brew --prefix)/var/log/ai-development-environment.err.log`.
