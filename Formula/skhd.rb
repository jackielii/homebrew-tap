class Skhd < Formula
  desc "Simple hotkey-daemon for macOS"
  homepage "https://github.com/jackielii/skhd"
  url "https://github.com/jackielii/skhd/archive/refs/tags/v0.3.9a.tar.gz"
  sha256 "884c1b0774db85478cae2f4757c76623fde05a6514f4b54505d76aff181f1015"
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
