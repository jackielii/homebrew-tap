class SkhdZig < Formula
  desc "Simple hotkey daemon for macOS, written in Zig"
  homepage "https://github.com/jackielii/skhd.zig"
  version "0.0.15-preview"
  
  if Hardware::CPU.intel?
    url "https://github.com/jackielii/skhd.zig/releases/download/v0.0.15-preview/skhd-x86_64-macos.tar.gz"
    sha256 "cf000ead4b0a52fdd4ed44cc2e098687417299f2258804bca6b7aa84a6285d5f"
  elsif Hardware::CPU.arm?
    url "https://github.com/jackielii/skhd.zig/releases/download/v0.0.15-preview/skhd-arm64-macos.tar.gz"
    sha256 "ffb805ac075d3df1c6a4a709360b8c61942148272c0a4cbe6ec08df7825baafc"
  end

  head "https://github.com/jackielii/skhd.zig.git", branch: "main"

  depends_on :macos

  def install
    if Hardware::CPU.intel?
      bin.install "skhd-x86_64-macos" => "skhd"
    elsif Hardware::CPU.arm?
      bin.install "skhd-arm64-macos" => "skhd"
    end
  end

  service do
    run [opt_bin/"skhd"]
    keep_alive true
    log_path "/tmp/skhd_#{ENV["USER"]}.log"
    environment_variables PATH: std_service_path_env
  end

  def caveats
    <<~EOS
      Create a configuration file in your home directory:
        touch ~/.config/skhd/skhdrc
      
      Check https://github.com/jackielii/skhd.zig/blob/main/SYNTAX.md

      If you want skhd to be managed by launchd (start automatically upon login):
        skhd --start-service

      When running as a launchd service logs will be found in:
        /tmp/skhd_#{ENV["USER"]}.log

      Note: skhd requires accessibility permissions.
      You'll be prompted to grant these permissions on first run.
    EOS
  end

  test do
    assert_match "skhd", shell_output("#{bin}/skhd --version")
  end
end
