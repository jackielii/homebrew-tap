# Documentation: https://docs.brew.sh/Formula-Cookbook
#                https://rubydoc.brew.sh/Formula
# PLEASE REMOVE ALL GENERATED COMMENTS BEFORE SUBMITTING YOUR PULL REQUEST!
class Rofi < Formula
  desc "Rofi: A window switcher, application launcher and dmenu replacement"
  homepage "https://github.com/davatorium/rofi"
  url "https://github.com/davatorium/rofi/releases/download/1.7.3/rofi-1.7.3.tar.gz"
  sha256 "608458775d0a8699dc31027e786aa9f3a63658ebfb98c5c807620a5889687ecc"
  license "MIT"
  head "https://github.com/davatorium/rofi.git", branch: "next"

  depends_on "cmake" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "bison" => :build
  depends_on "flex"
  depends_on "pango"
  # depends_on "libpangocairo" => :build
  depends_on "cairo"
  # depends_on "libcairo-xcb" => :build
  depends_on "glib"
  # depends_on "gmodule-2.0" => :build
  # depends_on "gio-unix-2.0" => :build
  depends_on "gdk-pixbuf"
  depends_on "startup-notification"
  depends_on "libxkbcommon"
  # depends_on "libxkbcommon-x11" => :build
  depends_on "libxcb"
  depends_on "xcb-util"
  depends_on "xcb-util-wm"
  depends_on "xcb-util-cursor"

  def install
    system "meson", "setup", "build", "--prefix=#{prefix}"
    system "ninja", "-C", "build"
    system "ninja", "-C", "build", "install"
  end

  test do
    # `test do` will create, run in and delete a temporary directory.
    #
    # This test will fail and we won't accept that! For Homebrew/homebrew-core
    # this will need to be a test that verifies the functionality of the
    # software. Run the test with `brew test rofi`. Options passed
    # to `brew install` such as `--HEAD` also need to be provided to `brew test`.
    #
    # The installed folder is not in the path, so use the entire path to any
    # executables being tested: `system "#{bin}/program", "do", "something"`.
    system "rofi", "-version"
  end
end
