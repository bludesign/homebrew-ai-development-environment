class AiDevelopmentEnvironment < Formula
  desc "AI-focused development environment"
  homepage "https://github.com/bludesign/ai-development-environment"
  url "https://github.com/bludesign/ai-development-environment/archive/refs/tags/v0.0.11.tar.gz"
  sha256 "576daccb98dce0fc602184eef708f6983aa0d0ceda9db203c331272f9b895a28"

  depends_on "node@24"

  def install
    system "npm", "ci"
    system "npm", "run", "build"

    libexec.install ".next/standalone"
    node = formula_opt_bin("node@24")/"node"

    # Self-contained Prisma toolchain so the service can apply migrations on start without the
    # app's dev dependencies. The Prisma 7 `prisma` package bundles a WASM schema engine, so
    # only it is required for `migrate deploy` (the SQLite driver adapter is a runtime-client
    # concern, not a migration one). prisma.config.js is plain CommonJS and reads DATABASE_URL
    # from the environment, avoiding any TypeScript/dotenv loading at service start.
    # Keep the pinned version in sync with the app's package.json.
    migrate_dir = libexec/"prisma-runtime"
    migrate_dir.mkpath
    migrate_dir.install "prisma"
    (migrate_dir/"prisma.config.js").write <<~JS
      const path = require("node:path");
      const { defineConfig } = require("prisma/config");

      module.exports = defineConfig({
        schema: path.join(__dirname, "prisma", "schema.prisma"),
        datasource: { url: process.env.DATABASE_URL },
      });
    JS
    # The standalone Prisma CLI is installed into its own prefix purely as a migration tool
    # for the service; this is separate from the app that `npm run build` produced.
    migrate_install_args = ["install", "--prefix", migrate_dir, "prisma@7.8.0"]
    system "npm", *migrate_install_args

    config = buildpath/"ai-development-environment.env"
    config.write <<~ENV
      HOSTNAME=127.0.0.1
      PORT=3090
      AGENT_WS_HOSTNAME=127.0.0.1
      AGENT_WS_PORT=3091
      DATABASE_URL=file:#{var}/ai-development-environment/production.db
    ENV
    etc.install config

    (bin/"ai-development-environment").write <<~BASH
      #!/bin/bash
      set -euo pipefail

      runtime_hostname="$(printenv HOSTNAME || true)"
      runtime_port="$(printenv PORT || true)"
      runtime_agent_ws_hostname="$(printenv AGENT_WS_HOSTNAME || true)"
      runtime_agent_ws_port="$(printenv AGENT_WS_PORT || true)"
      runtime_database_url="$(printenv DATABASE_URL || true)"
      configured_hostname="127.0.0.1"
      configured_port="3090"
      configured_agent_ws_hostname="127.0.0.1"
      configured_agent_ws_port="3091"
      configured_database_url="file:#{var}/ai-development-environment/production.db"

      if [[ -r "#{etc}/ai-development-environment.env" ]]; then
        unset HOSTNAME PORT AGENT_WS_HOSTNAME AGENT_WS_PORT DATABASE_URL
        source "#{etc}/ai-development-environment.env"
        configured_hostname="${HOSTNAME:-$configured_hostname}"
        configured_port="${PORT:-$configured_port}"
        configured_agent_ws_hostname="${AGENT_WS_HOSTNAME:-$configured_agent_ws_hostname}"
        configured_agent_ws_port="${AGENT_WS_PORT:-$configured_agent_ws_port}"
        configured_database_url="${DATABASE_URL:-$configured_database_url}"
      fi

      export HOSTNAME="${runtime_hostname:-$configured_hostname}"
      export PORT="${runtime_port:-$configured_port}"
      export AGENT_WS_HOSTNAME="${runtime_agent_ws_hostname:-$configured_agent_ws_hostname}"
      export AGENT_WS_PORT="${runtime_agent_ws_port:-$configured_agent_ws_port}"
      export DATABASE_URL="${runtime_database_url:-$configured_database_url}"

      # Prisma's SQLite migration engine expects the database file to exist before the first
      # `migrate deploy`. Create it without truncating an existing database.
      if [[ "$DATABASE_URL" == file:* ]]; then
        database_path="${DATABASE_URL#file:}"
        mkdir -p "$(dirname "$database_path")"
        if [[ ! -e "$database_path" ]]; then
          touch "$database_path"
        fi
      fi

      # Apply any pending database migrations before starting the server. This is a safe no-op
      # until the schema gains its first migration. Fail fast rather than serve against a
      # database whose migrations could not be applied.
      if ! (
        cd "#{opt_libexec}/prisma-runtime"
        "#{node}" node_modules/prisma/build/index.js migrate deploy
      ); then
        echo "ai-development-environment: database migration failed; not starting server" >&2
        exit 1
      fi

      exec "#{node}" "#{opt_libexec}/standalone/server.js"
    BASH
  end

  # Writable, upgrade-persistent location for the SQLite database (the Cellar/working_dir is
  # read-only). Paths inside post_install_steps are relative to Homebrew's var directory, so
  # this creates var/ai-development-environment, where the default DATABASE_URL points.
  post_install_steps do
    mkdir_p "ai-development-environment"
  end

  def caveats
    <<~EOS
      The service listens on http://127.0.0.1:3090 and serves agent GraphQL WebSockets
      on ws://127.0.0.1:3091/graphql by default. It stores its SQLite
      database at #{var}/ai-development-environment/production.db.

      Edit #{etc}/ai-development-environment.env and restart the service to change the
      bind addresses, ports, or the SQLite DATABASE_URL.
    EOS
  end

  service do
    run opt_bin/"ai-development-environment"
    keep_alive true
    working_dir opt_libexec/"standalone"
    log_path var/"log/ai-development-environment.log"
    error_log_path var/"log/ai-development-environment.err.log"
  end

  test do
    port = free_port
    agent_ws_port = free_port
    output = testpath/"server.log"
    pid = spawn(
      {
        "HOSTNAME"      => "127.0.0.1",
        "PORT"          => port.to_s,
        "AGENT_WS_PORT" => agent_ws_port.to_s,
        "DATABASE_URL"  => "file:#{testpath}/test.db",
      },
      bin/"ai-development-environment",
      [:out, :err] => output.to_s,
    )

    begin
      response = shell_output("curl --location --retry 10 --retry-delay 1 --retry-connrefused --silent http://127.0.0.1:#{port}")
      assert_match "To get started, edit the page.tsx file.", response

      graphql = shell_output(
        "curl --retry 10 --retry-delay 1 --retry-connrefused --silent " \
        "-X POST http://127.0.0.1:#{port}/api/graphql " \
        "-H 'content-type: application/json' " \
        "--data '{\"query\":\"{ health }\"}'",
      )
      assert_match "\"health\":\"ok\"", graphql
    ensure
      Process.kill("TERM", pid)
      Process.wait(pid)
    end
  end
end
