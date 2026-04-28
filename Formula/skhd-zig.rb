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
  url "https://github.com/jackielii/skhd.zig/releases/download/v0.0.24/skhd-arm64-macos.tar.gz"
  sha256 "cfc91c1e6f9f6eb78a2dd1a5650016fc132f3dc0e46c68576732f8838e38fadd"
  # if Hardware::CPU.intel?
  #   url "https://github.com/jackielii/skhd.zig/releases/download/v0.0.24/skhd-x86_64-macos.tar.gz"
  #   sha256 "cedab4892b025626ca68bd053067024787c08780eea301b2e32b36acbf504fa7"
  # end

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

  def post_install
    # Symlink the bundle into /Applications so SMAppService, TCC entries,
    # and `zig build install-local` all resolve `/Applications/skhd.app`
    # consistently. Without this, the bundle lives at
    # /opt/homebrew/Cellar/skhd-zig/<ver>/skhd.app and Privacy & Security
    # surfaces it under a non-obvious path while install-local writes to
    # a different prefix — same bytes, different path-keyed grants.
    target = prefix/"skhd.app"
    link = Pathname.new("/Applications/skhd.app")
    if link.exist? && !link.symlink?
      opoo "/Applications/skhd.app exists and is not a symlink — leaving alone"
    elsif link.symlink? && link.realpath != target.realpath
      ohai "Updating /Applications/skhd.app symlink → #{target}"
      link.unlink
      ln_s target, link
    elsif !link.exist?
      ohai "Linking #{target} into /Applications"
      ln_s target, link
    end
  rescue => e
    opoo "Could not symlink to /Applications: #{e.message}"
  end

  def post_uninstall
    # Remove the symlink we created in post_install. Only act if it points
    # at our keg — never delete a non-symlink or a link the user repointed.
    link = Pathname.new("/Applications/skhd.app")
    return unless link.symlink?
    target = link.readlink.to_s
    if target.include?("/Cellar/skhd-zig/") || target == (prefix/"skhd.app").to_s
      link.unlink
    end
  rescue
    # Best-effort; uninstall shouldn't fail because of a stale symlink.
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
    EOS

    bundle_caveats = <<~EOS

      App bundle:
        /Applications/skhd.app → #{opt_prefix}/skhd.app
        (symlink auto-created by this formula's post_install; survives
        brew upgrade so TCC entries keyed on this path stay valid).

      First-run setup:
        skhd --install-service
        # macOS will pop up two consent dialogs the first time:
        #   - Accessibility (always required)
        #   - Input Monitoring (only if your config has .remap / .taphold rules)
        # Both apply to skhd.app's bundle ID — one click per dialog, no
        # need to navigate Privacy & Security manually.
        skhd --status   # verify

      Tap-hold / remap rules (.remap, .taphold, fn_layer):
        --install-service prompts (Y/n) to install skhd-grabber as a system
        LaunchDaemon (asks for sudo password). The grabber runs from inside
        skhd.app — same bundle ID — so Input Monitoring granted to the
        agent covers the grabber too via bundle-shared TCC.

        On a machine without Karabiner-Elements, --install-grabber also
        installs the Karabiner-DriverKit-VirtualHIDDevice .pkg (one-time
        ~3MB download) and writes a LaunchDaemon plist for its userland
        daemon. If Karabiner-Elements is already installed, we detect that
        and skip — they share the same daemon label and KE manages it via
        SMAppService.

      Logs:
        ~/Library/Logs/skhd.log    (agent)
        /var/log/skhd-grabber.log  (grabber daemon, .remap users only)

      Uninstall (full cleanup):
        skhd --uninstall-service           # remove LaunchAgent
        sudo skhd --uninstall-grabber      # remove grabber + VHIDD daemon
                                           # (Karabiner DriverKit pkg + the
                                           # kernel dext are pqrs's domain;
                                           # --uninstall-service prints
                                           # the exact follow-up commands)
        brew uninstall skhd-zig            # cleans /Applications symlink

      Upgrading from 0.0.17 or earlier? See:
        https://github.com/jackielii/skhd.zig/blob/main/docs/UPGRADING.md

      Migrating from `brew services start skhd-zig`? The brew-services
      integration was removed in 0.0.18. Run:
        brew services stop skhd-zig 2>/dev/null
        skhd --install-service
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
