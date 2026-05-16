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
  url "https://github.com/jackielii/skhd.zig/releases/download/v0.1.3/skhd-arm64-macos.tar.gz"
  sha256 "1be1ec4a2fc211dcd2b70f3d777601abd3330365ca4e84edb6ed9370bad54120"
  # if Hardware::CPU.intel?
  #   url "https://github.com/jackielii/skhd.zig/releases/download/v0.1.3/skhd-x86_64-macos.tar.gz"
  #   sha256 "ecf492be56b8724e1042ee5c9a7553ff6e935772f49b01547c420fe0d070d246"
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

  # Auto-run `--restart-service` after every install/upgrade. Closes the
  # "service didn't restart after `brew upgrade`" gap. We use restart,
  # not start, on purpose: brew replaces the on-disk binary but the
  # running launchd process keeps the old binary's text mapped (Unix
  # semantics — the inode lives on while a process holds it open), so a
  # plain `--start-service` is a no-op against an already-running agent
  # and the user is left running the previous version with no signal
  # that anything is stale. `--restart-service` does
  # `launchctl bootout` (no-op if nothing is running, so this is also
  # safe on first install) → 1s pause → registerWithBTM, which spawns
  # a fresh process from the new Cellar bundle.
  #
  # Restart also folds in the cleanupLegacyInstall step that boots out
  # any pre-0.0.21 hand-installed plist at
  # ~/Library/LaunchAgents/com.jackielii.skhd.plist (which silently
  # shadows the SMAppService registration on Tahoe — same Label, two
  # definitions = launchd refuses to spawn either with EX_CONFIG).
  def post_install
    # Best-effort: a failure here shouldn't abort the install (the
    # binary is on disk and the user can recover by hand), but we want
    # the output visible so they see what happened.
    system bin/"skhd", "--restart-service"
  rescue => e
    opoo "skhd --restart-service failed during post_install: #{e.message}"
    opoo "Run `skhd --restart-service` manually to finish setup."
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
