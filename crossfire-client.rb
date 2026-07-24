class CrossfireClient < Formula
  desc "Crossfire is a free, open-source, cooperative multiplayer RPG and adventure game"
  homepage "https://sourceforge.net/projects/crossfire/"
  license "GPL-2.0-only"

  stable do
    url "https://downloads.sourceforge.net/code-snapshots/git/c/cr/crossfire/crossfire-client.git/crossfire-crossfire-client-e196986b41fefdc130be146f0ea565c7f2c09ff4.zip"
    version "1.75.5"
    sha256 "0edfdb53ae9533e5973e3436cafd3bed222d0c3c520f34adf9bc7bea5f2537fb"

    resource "crossfire-sounds" do
      url "https://downloads.sourceforge.net/code-snapshots/git/c/cr/crossfire/crossfire-sounds.git/crossfire-crossfire-sounds-8d136fbf62928c765af3aac62b48845fa01c5359.zip"
      sha256 "a3246db222a97efea51c760420efe46d4d8b63b6f755df2c0979f5e59307a623"
    end

    patch :p1, :DATA
  end

  head do
    url "https://git.code.sf.net/p/crossfire/crossfire-client.git", branch: "gtk3"

    resource "crossfire-sounds" do
      url "git://git.code.sf.net/p/crossfire/crossfire-sounds"
    end

    patch :p1, :DATA
  end

  depends_on "cmake" => :build
  depends_on "vala" => :build
  depends_on "at-spi2-core"
  depends_on "cairo"
  depends_on "curl"
  depends_on "gdk-pixbuf"
  depends_on "gettext"
  depends_on "glib"
  depends_on "gtk+3"
  depends_on "harfbuzz"
  depends_on "libpng"
  depends_on "libx11"
  depends_on "libxext"
  depends_on "lua@5.4"
  depends_on "pango"
  depends_on "sdl2"
  depends_on "sdl2_mixer"

  def install
    ENV.append_to_cflags "-DHAVE_OPENGL"
    ENV.append_to_cflags "-DHAVE_SDL"
    ENV.append_to_cflags "-DENABLE_NLS"
    ENV.append_to_cflags "-DGETTEXT_PACKAGE=\\\"crossfire-client\\\""
    ENV.append_to_cflags "-DPACKAGE_LOCALE_DIR=\\\"#{share}/locale\\\""

    resource("crossfire-sounds").unpack(buildpath/"sounds")

    system "cmake", "-S", ".", "-B", "build", "-DLUA=ON", *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    assert_path_exists bin/"crossfire-client-gtk2"
  end
end
__END__
diff --git a/gtk-v2/src/keys.c b/gtk-v2/src/keys.c
index 155c4e6..c0e97a8 100644
--- a/gtk-v2/src/keys.c
+++ b/gtk-v2/src/keys.c
@@ -22,8 +22,13 @@
 #include <gdk/gdkkeysyms.h>
 #include <gtk/gtk.h>
 
-#ifndef WIN32
+#if !defined(WIN32) && !defined(__APPLE__)
 #include <gdk/gdkx.h>
+#elif defined(__APPLE__)
+#include <gdk/gdkquartz.h>
+#define NoSymbol 0L                     /**< Special KeySym */
+typedef int KeyCode;                    /**< Undefined type */
+
 #else
 #include <gdk/gdkwin32.h>
 #define NoSymbol 0L                     /**< Special KeySym */
diff --git a/gtk-v2/src/main.c b/gtk-v2/src/main.c
index ceb3512..67656b0 100644
--- a/gtk-v2/src/main.c
+++ b/gtk-v2/src/main.c
@@ -25,7 +25,9 @@
 #ifndef WIN32
 #include <signal.h>
 #endif
-
+#if defined(__APPLE__) && defined(ENABLE_NLS)
+#include <libintl.h>
+#endif
 #ifdef HAVE_CAPSICUM
 #include <sys/capsicum.h>
 #endif
