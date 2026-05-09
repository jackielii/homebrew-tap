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
  url "https://github.com/jackielii/skhd.zig/releases/download/v0.1.1/skhd-arm64-macos.tar.gz"
  sha256 "7e468af301b072d9cc9e797fafc1f1c4c2751a8201850839a94a79ead3294f94"
  # if Hardware::CPU.intel?
  #   url "https://github.com/jackielii/skhd.zig/releases/download/v0.1.1/skhd-x86_64-macos.tar.gz"
  #   sha256 "d9b43be7f7b558f088ab8988241ef012cd902775b5e0e21182870895b768462c"
  # end

  depends_on :macos

  # Starting in 0.0.18 the release tarball contains skhd.app rather than a bare
  # `skhd` binary. The 0.0.17 tarball still ships a bare binary; install layout
  # branches on what's actually in the payload so this formula keeps working
  # for users still on the old release until the auto-bump runs.
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
    else
      odie "skhd-zig payload did not contain a recognised layout"
    end
  end

  # `brew services` integration was removed in 0.0.18 — its generated plist
  # is a strict subset of skhd's own and the two would race for the event
  # tap. Setup goes through `skhd --start-service` (see caveats).

  # Auto-run `--start-service` after every install/upgrade. Closes the
  # "service didn't restart after `brew upgrade`" gap: --start-service is
  # idempotent and folds in the cleanupLegacyInstall step that boots out
  # any pre-0.0.21 hand-installed plist at
  # ~/Library/LaunchAgents/com.jackielii.skhd.plist (which silently
  # shadows the SMAppService registration on Tahoe — same Label, two
  # definitions = launchd refuses to spawn either with EX_CONFIG).
  # Re-registering with BTM also re-binds SMAppService to the *current*
  # versioned Cellar bundle path so the new binary actually gets used.
  def post_install
    # Best-effort: a failure here shouldn't abort the install (the
    # binary is on disk and the user can recover by hand), but we want
    # the output visible so they see what happened.
    system bin/"skhd", "--start-service"
  rescue => e
    opoo "skhd --start-service failed during post_install: #{e.message}"
    opoo "Run `skhd --start-service` manually to finish setup."
  end

  def caveats
    <<~EOS
      Configuration:
        touch ~/.config/skhd/skhdrc

      Syntax reference:
        https://github.com/jackielii/skhd.zig/blob/main/SYNTAX.md

      Setup is now automatic: `skhd --start-service` runs in post_install
      after every `brew install` / `brew upgrade`, registering the agent
      with macOS Background Tasks Manager and cleaning up any pre-0.0.21
      legacy plist that might shadow the SMAppService registration.

      First-time install only — grant permissions when prompted:
        - System Settings → Privacy & Security → Accessibility (toggle skhd on)
        - Press any hotkey to trigger the Input Monitoring prompt; approve

      To re-run setup manually (idempotent — safe anytime):
        skhd --start-service
        skhd --status   # verify

      Optional — surface the bundle under /Applications:
        ln -sfn #{opt_prefix}/skhd.app /Applications/skhd.app

      Logs:
        ~/Library/Logs/skhd.log    (agent)
        /var/log/skhd-grabber.log  (grabber, if installed)

      Uninstall:
        skhd --uninstall-service
        sudo skhd --uninstall-grabber   # if installed
        brew uninstall skhd-zig

      Migrating from `brew services start skhd-zig`:
        brew services stop skhd-zig 2>/dev/null
        skhd --start-service
    EOS
  end

  test do
    assert_match "skhd", shell_output("#{bin}/skhd --version")
  end
end
