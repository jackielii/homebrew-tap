class MySkhd < Formula
  desc "Simple hotkey-daemon for macOS"
  homepage "https://github.com/jackielii/skhd"
  url "https://github.com/jackielii/skhd/archive/refs/tags/v0.3.9b.tar.gz"
  sha256 "9469267811fd87dec2b714c69463fc0e8125ea379da9cdd20f44d7ecca286988"
  head "https://github.com/jackielii/skhd.git"

  def install
    ENV.deparallelize
    system "make", "-j1", "install"
    bin.install "#{buildpath}/bin/skhd"
    (pkgshare/"examples").install "#{buildpath}/examples/skhdrc"
  end

  def caveats
    <<~EOS
      Copy the example configuration into your home directory:
        cp #{pkgshare}/examples/skhdrc ~/.skhdrc

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
