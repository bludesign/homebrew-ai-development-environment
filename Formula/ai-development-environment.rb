class AiDevelopmentEnvironment < Formula
  desc "AI-focused development environment"
  homepage "https://github.com/bludesign/ai-development-environment"
  url "https://github.com/bludesign/ai-development-environment/archive/refs/tags/v0.0.7.tar.gz"
  sha256 "6af4f65b5163d840f44d91ca8f003d9d7ceb2ef023242f5c269655e3ff879dd3"

  depends_on "node@24"

  def install
    system "npm", "ci"
    system "npm", "run", "build"

    libexec.install ".next/standalone"
    node = formula_opt_bin("node@24")/"node"

    config = buildpath/"ai-development-environment.env"
    config.write <<~ENV
      HOSTNAME=127.0.0.1
      PORT=3090
    ENV
    etc.install config

    (bin/"ai-development-environment").write <<~BASH
      #!/bin/bash
      set -euo pipefail

      runtime_hostname="$(printenv HOSTNAME || true)"
      runtime_port="$(printenv PORT || true)"
      configured_hostname="127.0.0.1"
      configured_port="3090"

      if [[ -r "#{etc}/ai-development-environment.env" ]]; then
        unset HOSTNAME PORT
        source "#{etc}/ai-development-environment.env"
        configured_hostname="${HOSTNAME:-$configured_hostname}"
        configured_port="${PORT:-$configured_port}"
      fi

      export HOSTNAME="${runtime_hostname:-$configured_hostname}"
      export PORT="${runtime_port:-$configured_port}"

      exec "#{node}" "#{opt_libexec}/standalone/server.js"
    BASH
  end

  def caveats
    <<~EOS
      The service listens on http://127.0.0.1:3090 by default.
      Edit #{etc}/ai-development-environment.env and restart the service to
      change the bind address or port.
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
    output = testpath/"server.log"
    pid = spawn(
      { "HOSTNAME" => "127.0.0.1", "PORT" => port.to_s },
      bin/"ai-development-environment",
      [:out, :err] => output.to_s,
    )

    begin
      response = shell_output("curl --retry 10 --retry-delay 1 --retry-connrefused --silent http://127.0.0.1:#{port}")
      assert_match "To get started, edit the page.tsx file.", response
    ensure
      Process.kill("TERM", pid)
      Process.wait(pid)
    end
  end
end
