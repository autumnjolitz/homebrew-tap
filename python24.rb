class Python24 < Formula
  desc "This is the Homebrew formula for Python 2.4"
  homepage "http://www.python.org/"
  url "https://www.python.org/ftp/python/2.4.6/Python-2.4.6.tar.bz2"
  sha256 "da104139ad3f4534482942ac02cf8f8ed9badd370ffa14f06b07c44914423e08"

  option "with-framework", "Do a 'Framework' build instead of a UNIX-style build."
  option "with-universal", "Build for both 32 & 64 bit Intel."
  option "with-static", "Build static libraries."

  depends_on "gdbm" => :optional
  depends_on "readline" => :optional  # Prefer over OS X's libedit
  depends_on "sqlite" => :optional    # Prefer over OS X's older version

  patch :p1, :DATA

  def site_packages
    # The Cellar location of site-packages
    if build.with? "framework"
      # If we're installed or installing as a Framework, then use that location.
      frameworks / "Python.framework"/"Versions"/"2.4"/"lib"/"python2.4"/"site-packages"
    else
      # Otherwise, use just the lib path.
      lib / "python2.4"/"site-packages"
    end
  end

  def prefix_site_packages
    # The HOMEBREW_PREFIX location of site-packages
    lib/"python2.4"/"site-packages"
  end

  def validate_options
    if (build.with? "framework") && (build.with? "static")
      onoe "Cannot specify both framework and static."
      exit 99
    end
  end

  def install
    validate_options

    args = [
      "--prefix=#{prefix}",
      "--disable-toolbox-glue",
      "--enable-unicode=ucs2",
      "--disable-ipv6",
      "--with-fpectl",
      "--mandir=#{man}",
    ]

    if build.with? "universal"
      args << "--enable-universalsdk=/"
      args << "--with-universal-archs=intel"
    end

    if build.with? "framework"
      args << "--enable-framework=#{frameworks}"
    elsif build.without? "static"
      args << "--enable-shared"
    end

    ENV.append_to_cflags "-D_DARWIN_C_SOURCE"
    system "./configure", *args

    inreplace "pyconfig.h" do |s|
      s.gsub!("_POSIX_C_SOURCE", "_DARWIN_C_SOURCE")
    end

    inreplace "Modules/Setup" do |s|
      s.gsub!("#*shared*", "*shared*")
      s.gsub!("#_socket", "_socket")
      s.gsub!("#grp", "grp")
      s.gsub!("#select", "select")
      s.gsub!("#_csv", "_csv")
      s.gsub!("#mmap", "mmap")
      s.gsub!("#fcntl", "fcntl")
      s.gsub!("#unicodedata", "unicodedata")
      s.gsub!("#readline", "readline")
      s.gsub!("#array", "array")
      s.gsub!("#cmath", "cmath")
      s.gsub!("#math", "math")
      s.gsub!("#struct", "struct")
      s.gsub!("#time", "time")
      s.gsub!("#operator", "operator")
      s.gsub!("#_weakref", "_weakref")
      s.gsub!("#_random", "_random")
      s.gsub!("#collections", "collections")
      s.gsub!("#itertools", "itertools")
      s.gsub!("#resource", "resource")
      s.gsub!("#_locale", "_locale")
      s.gsub!("#zlib", "zlib")
    end

    system "make"
    # ARJ: make has to run twice in order to build
    # the expected socket, et al
    # This is NOT a duplicate line. It literally makes
    # the difference between a partial and full install
    system "make"
    ENV.deparallelize # Some kinds of installs must be serialized.
    system "make", "altinstall"

    # Add the Homebrew prefix path to site-packages via a .pth
    prefix_site_packages.mkpath
    (site_packages/"homebrew.pth").write prefix_site_packages
  end

  def caveats
    framework_caveats = <<-EOS
      Framework Python was installed to:
        #{frameworks}/Python.framework

      You may want to symlink this Framework to a standard OS X location,
      such as:
        mkdir ~/Frameworks
        ln -s "#{frameworks}/Python.framework" ~/Frameworks

    EOS

    site_caveats = <<-EOS
      The site-packages folder for this Python is:
        #{site_packages}

      We've added a "homebrew.pth" file to also include:
        #{prefix_site_packages}

    EOS

    general_caveats = <<-EOS
      You may want to create a "virtual environment" using this Python as a base
      so you can manage multiple independent site-packages. See:
        http://pypi.python.org/pypi/virtualenv

      If you install Python packages via pip, binaries will be installed under
      Python's cellar but not automatically linked into the Homebrew prefix.
      You may want to add Python's bin folder to your PATH as well:
        #{bin}
    EOS

    s = site_caveats+general_caveats
    s = framework_caveats + s if build.with? "framework"
    s
  end

  test do
    system "${bin}/python2.4", "--help"
  end
end
__END__
diff --git a/Modules/fcntlmodule.c b/Modules/fcntlmodule.c
index 0c02ee6..2fdd347 100644
--- a/Modules/fcntlmodule.c
+++ b/Modules/fcntlmodule.c
@@ -13,6 +13,8 @@
 #include <stropts.h>
 #endif
 
+extern int flock(int fd, int operation);
+
 static int
 conv_descriptor(PyObject *object, int *target)
 {
diff --git a/Modules/getaddrinfo.c b/Modules/getaddrinfo.c
index 4d19c34..9d5afc8 100644
--- a/Modules/getaddrinfo.c
+++ b/Modules/getaddrinfo.c
@@ -57,6 +57,13 @@
 #include "addrinfo.h"
 #endif
 
+#include <netinet/in.h>
+#include <arpa/inet.h>
+
+typedef unsigned short u_short;
+typedef unsigned long u_long;
+typedef unsigned char u_char;
+
 #if defined(__KAME__) && defined(ENABLE_IPV6)
 # define FAITH
 #endif
diff --git a/Modules/posixmodule.c b/Modules/posixmodule.c
index dc7f723..741e310 100644
--- a/Modules/posixmodule.c
+++ b/Modules/posixmodule.c
@@ -23,6 +23,9 @@
 #  pragma weak statvfs
 #  pragma weak fstatvfs
 
+#include <sys/types.h>
+#include <sys/disk.h>
+
 #endif /* __APPLE__ */
 
 #include "Python.h"
@@ -155,6 +158,9 @@ corresponding Unix manual entries for more information on calls.");
    (default) */
 extern char        *ctermid_r(char *);
 #endif
+extern int getloadavg(double[], int);
+extern char *ctermid_r(char *buf);
+extern int setgroups(int ngroups, const gid_t *gidset);
 
 #ifndef HAVE_UNISTD_H
 #if defined(PYCC_VACPP)
