class Rofi < Formula
  desc "Window switcher, application launcher and dmenu replacement"
  homepage "https://github.com/davatorium/rofi"
  url "https://github.com/davatorium/rofi/releases/download/1.7.3/rofi-1.7.3.tar.gz"
  sha256 "608458775d0a8699dc31027e786aa9f3a63658ebfb98c5c807620a5889687ecc"
  license "MIT"
  head "https://github.com/davatorium/rofi.git", branch: "next"

  depends_on "bison" => :build
  depends_on "cmake" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "cairo"
  depends_on "flex"
  depends_on "gdk-pixbuf"
  depends_on "glib"
  depends_on "libxcb"
  depends_on "libxkbcommon"
  depends_on "pango"
  depends_on "startup-notification"
  depends_on "xcb-util"
  depends_on "xcb-util-cursor"
  depends_on "xcb-util-wm"

  def install
    system "meson", "setup", "build", "--prefix=#{prefix}"
    system "ninja", "-C", "build"
    system "ninja", "-C", "build", "install"
  end

  test do
    system "#{bin}/rofi", "-version"
  end
end
