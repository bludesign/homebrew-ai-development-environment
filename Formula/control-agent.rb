class ControlAgent < Formula
  desc "Outbound macOS control agent for AI Development Environment"
  homepage "https://github.com/bludesign/ai-development-environment"
  url "https://github.com/bludesign/ai-development-environment/archive/refs/tags/v0.0.33.tar.gz"
  sha256 "4cb141686605b9ca002cb2c91221c31a5702efe4f2cf19404b7031869fc3dde8"
  head "https://github.com/bludesign/ai-development-environment.git", branch: "main"

  depends_on "cloudflared"
  depends_on "node@24"

  def install
    system "npm", "ci"
    system "npm", "run", "agent:build"

    libexec.install "packages/control-agent/dist/control-agent.js"
    node = formula_opt_bin("node@24")/"node"
    (bin/"control-agent").write <<~BASH
      #!/bin/bash
      exec "#{node}" "#{opt_libexec}/control-agent.js" "$@"
    BASH
  end

  def caveats
    <<~EOS
      Enroll this Mac before starting the service:

        control-agent enroll \
          --server http://127.0.0.1:3090 \
          --enrollment-token <one-time-token>

      Then start the persistent launchd service:

        brew services start control-agent

      Credentials are stored with mode 0600 at:
        ~/.config/control-agent/config.json
    EOS
  end

  service do
    run opt_bin/"control-agent", "run"
    keep_alive true
    process_type :background
    log_path var/"log/control-agent.log"
    error_log_path var/"log/control-agent.err.log"
  end

  test do
    assert_match "enroll", shell_output("#{bin}/control-agent --help")
    assert_match "doctor", shell_output("#{bin}/control-agent --help")
  end
end
