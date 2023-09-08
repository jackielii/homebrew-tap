class Skhd < Formula
  desc "Simple hotkey-daemon for macOS."
  homepage "https://github.com/jackielii/skhd"
  url "https://github.com/jackielii/skhd/archive/refs/tags/v0.3.9.zip"
  sha256 "d31395c87b26c33a8eb9f086846b5c7d145ab01a2351ee3f752a1bae30759263"
  head "https://github.com/jackielii/skhd.git"

  def install
    ENV.deparallelize
    system "make", "-j1", "install"
    bin.install "#{buildpath}/bin/skhd"
    (pkgshare/"examples").install "#{buildpath}/examples/skhdrc"
  end

  def caveats; <<~EOS
    Copy the example configuration into your home directory:
      cp #{opt_pkgshare}/examples/skhdrc ~/.skhdrc

    If you want skhd to be managed by launchd (start automatically upon login):
      skhd --start-service

    When running as a launchd service logs will be found in:
      /tmp/skhd_<user>.[out|err].log
    EOS
  end

  test do
    assert_match "skhd-v#{version}", shell_output("#{bin}/skhd --version")
  end
end
