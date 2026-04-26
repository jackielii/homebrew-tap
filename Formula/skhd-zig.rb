class SkhdZig < Formula
  desc "Simple hotkey daemon for macOS, written in Zig"
  homepage "https://github.com/jackielii/skhd.zig"

  if Hardware::CPU.intel?
    url "https://github.com/jackielii/skhd.zig/releases/download/v0.0.17/skhd-x86_64-macos.tar.gz"
    sha256 "4d405ad06532d4e6c9fb215c4b84d3fb2d1c3d861d09dc5d058be3ed1daaecfc"
  elsif Hardware::CPU.arm?
    url "https://github.com/jackielii/skhd.zig/releases/download/v0.0.17/skhd-arm64-macos.tar.gz"
    sha256 "d65bef42850e0b1a6eb34ecbe4ab06d65df4188f8b3fe2a4bcb190375d8a161b"
  end

  head "https://github.com/jackielii/skhd.zig.git", branch: "main"

  depends_on "zig" => :build
  depends_on :macos

  # Starting in 0.0.18 the release tarball contains skhd.app rather than a bare
  # `skhd` binary. The 0.0.17 tarball still ships a bare binary; install layout
  # branches on what's actually in the payload so this formula keeps working
  # for users still on the old release until the auto-bump runs, and also
  # supports `brew install --HEAD` which gives us a source checkout.
  def install
    if File.directory?("skhd.app")
      # 0.0.18+ release tarball: pre-built .app bundle
      prefix.install "skhd.app"
      bin.install_symlink prefix/"skhd.app/Contents/MacOS/skhd"
    elsif File.exist?("skhd-x86_64-macos")
      bin.install "skhd-x86_64-macos" => "skhd"
    elsif File.exist?("skhd-arm64-macos")
      bin.install "skhd-arm64-macos" => "skhd"
    elsif File.exist?("build.zig")
      # --HEAD install: build the bundle from source. Code signing uses the
      # user's login keychain so it has to happen post-install, not here.
      system "zig", "build", "app", "-Doptimize=ReleaseFast"
      prefix.install "zig-out/skhd.app"
      bin.install_symlink prefix/"skhd.app/Contents/MacOS/skhd"
    else
      odie "skhd-zig payload did not contain skhd.app, a recognised binary, or build.zig"
    end
  end

  service do
    run [opt_bin/"skhd"]
    keep_alive true
    log_path "#{Dir.home}/Library/Logs/skhd.log"
    error_log_path "#{Dir.home}/Library/Logs/skhd.log"
    environment_variables PATH: std_service_path_env
  end

  def caveats
    base = <<~EOS
      Configuration:
        touch ~/.config/skhd/skhdrc

      Syntax reference:
        https://github.com/jackielii/skhd.zig/blob/main/SYNTAX.md

      Run skhd as a launchd service:
        skhd --install-service
        skhd --start-service
        skhd --status

      Logs (when running as a service):
        ~/Library/Logs/skhd.log
    EOS

    if (opt_prefix/"skhd.app").exist?
      bundle_caveats = <<~EOS

        Accessibility permission (.app bundle install):
          1. Symlink the bundle into /Applications so System Settings can find it:
               ln -sfn #{opt_prefix}/skhd.app /Applications/skhd.app
          2. Open System Settings → Privacy & Security → Accessibility
          3. Click '+', add /Applications/skhd.app, toggle on
          4. Run: skhd --restart-service

        Upgrading from 0.0.17 or earlier? See:
          https://github.com/jackielii/skhd.zig/blob/main/docs/UPGRADING.md
      EOS
      base + bundle_caveats
    else
      legacy_caveats = <<~EOS

        Note: skhd requires accessibility permissions.
        You'll be prompted to grant these permissions on first run.
      EOS
      base + legacy_caveats
    end
  end

  test do
    assert_match "skhd", shell_output("#{bin}/skhd --version")
  end
end
