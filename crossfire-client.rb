class CrossfireClient < Formula
  desc "Crossfire is a free, open-source, cooperative multiplayer RPG and adventure game"
  homepage "https://sourceforge.net/projects/crossfire/"
  license "GPL-2.0-only"
  head "https://git.code.sf.net/p/crossfire/crossfire-client.git", branch: "gtk3"

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
  depends_on "pango"
  depends_on "sdl2"
  depends_on "sdl2_mixer"
  patch :p1, :DATA

  def install
    system "cmake", "-S", ".", "-B", "build", *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    system bin/"crossfire-client-gtk2", "--help-all"
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
