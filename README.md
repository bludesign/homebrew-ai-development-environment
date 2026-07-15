# AI Development Environment Homebrew Tap

## Install

```bash
brew tap bludesign/ai-development-environment
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

## Control agent

Until the first agent release is tagged, install the formula from the repository head:

```bash
brew install --HEAD control-agent
```

Create a one-time enrollment command from the app's **Agents** page, run it on the
Mac, then start the persistent outbound-only service:

```bash
control-agent enroll \
  --server http://127.0.0.1:3090 \
  --enrollment-token <one-time-token>
brew services start control-agent
```

The agent stores its stable ID and credential in
`~/.config/control-agent/config.json`. Service logs are at
`$(brew --prefix)/var/log/control-agent.log` and
`$(brew --prefix)/var/log/control-agent.err.log`.
