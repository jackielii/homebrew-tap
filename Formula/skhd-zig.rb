class SkhdZig < Formula
  desc "Simple hotkey daemon for macOS, written in Zig"
  homepage "https://github.com/jackielii/skhd.zig"

  # Apple Silicon only as of v0.0.18 (Intel builds paused — no demand,
  # macos-13 runners spend most of their time queued). To re-enable Intel:
  #   1. Wrap the url/sha pair below in `if Hardware::CPU.arm?`
  #   2. Uncomment the `Hardware::CPU.intel?` branch underneath
  #   3. Drop the `depends_on arch: :arm64` line
  #   4. Re-enable the matching matrix entry + auto-bump SHA in
  #      skhd.zig's release.yml (build-release matrix, update-homebrew job)
  url "https://github.com/jackielii/skhd.zig/releases/download/v0.0.20/skhd-arm64-macos.tar.gz"
  sha256 "7b34c605fc99b9be97935f1cd2c22cb8418ea829136d376f0a39605ab3217942"
  # if Hardware::CPU.intel?
  #   url "https://github.com/jackielii/skhd.zig/releases/download/v0.0.17/skhd-x86_64-macos.tar.gz"
  #   sha256 "4d405ad06532d4e6c9fb215c4b84d3fb2d1c3d861d09dc5d058be3ed1daaecfc"
  # end

  head "https://github.com/jackielii/skhd.zig.git", branch: "main"

  depends_on "zig" => :build
  depends_on arch: :arm64
  depends_on :macos

  # Starting in 0.0.18 the release tarball contains skhd.app rather than a bare
  # `skhd` binary. The 0.0.17 tarball still ships a bare binary; install layout
  # branches on what's actually in the payload so this formula keeps working
  # for users still on the old release until the auto-bump runs, and also
  # supports `brew install --HEAD` which gives us a source checkout.
  def install
    if File.directory?("skhd.app")
      # Pre-built .app bundle, top-level directory preserved
      prefix.install "skhd.app"
      bin.install_symlink prefix/"skhd.app/Contents/MacOS/skhd"
    elsif File.exist?("Contents/MacOS/skhd") && File.exist?("Contents/Info.plist")
      # Brew's unpacker auto-strips a single top-level directory — for our
      # 0.0.18+ tarballs that means it stripped `skhd.app/` and we're already
      # inside the bundle. Reconstruct skhd.app at the install prefix.
      app_dir = prefix/"skhd.app"
      app_dir.mkpath
      cp_r "Contents", app_dir
      bin.install_symlink app_dir/"Contents/MacOS/skhd"
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
      odie "skhd-zig payload did not contain a recognised layout"
    end
  end

  # `brew services` integration removed in 0.0.18. skhd's own `--install-service`
  # produces a launchd plist that's tuned for macOS Tahoe (retry loop, log path,
  # bootstrap/bootout, ThrottleInterval=10, bundle-aware ProgramArguments) — the
  # brew-services-generated plist is a strict subset and the two would race for
  # the event tap if both were enabled. Caveats below cover the migration.

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

    bundle_caveats = <<~EOS

      Accessibility permission (.app bundle install):
        1. Symlink the bundle into /Applications so System Settings can find it:
             ln -sfn #{opt_prefix}/skhd.app /Applications/skhd.app
        2. Open System Settings → Privacy & Security → Accessibility
        3. Click '+', add /Applications/skhd.app, toggle on
        4. Run: skhd --restart-service

      Upgrading from 0.0.17 or earlier? See:
        https://github.com/jackielii/skhd.zig/blob/main/docs/UPGRADING.md

      Migrating from `brew services start skhd-zig`? The brew-services
      integration was removed in 0.0.18. Run:
        brew services stop skhd-zig 2>/dev/null
        skhd --install-service
        skhd --start-service
    EOS

    legacy_caveats = <<~EOS

      Note: skhd requires accessibility permissions.
      You'll be prompted to grant these permissions on first run.
    EOS

    if (opt_prefix/"skhd.app").exist?
      base + bundle_caveats
    else
      base + legacy_caveats
    end
  end

  test do
    assert_match "skhd", shell_output("#{bin}/skhd --version")
  end
end
