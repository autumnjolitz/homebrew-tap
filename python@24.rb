class PythonAT24 < Formula
  desc "This is the Homebrew formula for Python 2.4"
  homepage "http://www.python.org/"
  url "https://www.python.org/ftp/python/2.4.6/Python-2.4.6.tar.bz2"
  sha256 "da104139ad3f4534482942ac02cf8f8ed9badd370ffa14f06b07c44914423e08"

  option "with-framework", "Do a 'Framework' build instead of a UNIX-style build."
  option "with-universal", "Build for both 32 & 64 bit Intel."
  option "with-ssl", "Build with legacy _ssl module"

  depends_on "libtool" => :build
  depends_on "gdbm"
  depends_on "openssl" => "with-ssl"
  depends_on "readline"

  patch :p1, :DATA

  resource "pip" do
    url "https://files.pythonhosted.org/packages/25/57/0d42cf5307d79913a082c5c4397d46f3793bc35e1138a694136d6e31be99/pip-1.1.tar.gz"
    sha256 "993804bb947d18508acee02141281c77d27677f8c14eaa64d6287a1c53ef01c8"
  end

  resource "setuptools" do
    url "https://files.pythonhosted.org/packages/61/3c/8d680267eda244ad6391fb8b211bd39d8b527f3b66207976ef9f2f106230/setuptools-1.4.2.tar.gz"
    sha256 "263986a60a83aba790a5bffc7d009ac88114ba4e908e5c90e453b3bf2155dbbd"
  end

  def site_packages
    # The Cellar location of site-packages
    if build.with? "framework"
      # If we're installed or installing as a Framework, then use that location.
      frameworks / "Python.framework" / "Versions" / "2.4" / "lib" / "python2.4" / "site-packages"
    else
      # Otherwise, use just the lib path.
      lib / "python2.4" / "site-packages"
    end
  end

  def prefix_site_packages
    # The HOMEBREW_PREFIX location of site-packages
    lib/"python2.4"/"site-packages"
  end

  def install
    # remap ppc to arm64 and i386 to x86_64
    # inreplace "configure" do |s|
    #   s.gsub!("ppc", "arm64")
    #   s.gsub!("i386", "x86_64")
    # end

    args = [
      "--prefix=#{prefix}",
      "--disable-toolbox-glue",
      "--enable-unicode=ucs2",
      "--disable-ipv6",
      "--with-fpectl",
      "--mandir=#{man}",
    ]

    if build.with? "universal"
      args << "--enable-universalsdk=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
      args << "--with-universal-archs=intel"
    end

    if build.with? "framework"
      args << "--enable-framework=#{frameworks}"
    else
      args << "--enable-shared"
    end

    ENV.append_to_cflags "-D_DARWIN_C_SOURCE"

    inreplace "Mac/OSX/Makefile.in" do |s|
      s.gsub!("/Library/Frameworks", frameworks.to_s)
    end
    system "./configure", *args
    ["Makefile.pre", "Makefile"].each do |target|
      inreplace target do |s|
        s.gsub!("-mno-fused-madd", "-ffp-contract=off")
      end
    end

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
      if build.with? "ssl"
        s.gsub!("#SSL=/usr/local/ssl", "SSL=#{HOMEBREW_PREFIX}/opt/openssl")
        s.gsub!("#_ssl", "_ssl")
        s.gsub!(/^#(\s)*-DUSE_SSL/, " -DUSE_SSL")
        s.gsub!(/^#(\s)*-L\$\(SSL\)\/lib/, " -L$(SSL)/lib")
      end
    end

    system "make"
    # tell python to double check the setup config
    FileUtils.touch('Modules/Setup')
    # ARJ: make has to run twice in order to build
    # the expected socket, et al
    # This is NOT a duplicate line. It literally makes
    # the difference between a partial and full install
    system "make"
    ENV.deparallelize # Some kinds of installs must be serialized.
    system "make", "altinstall"

    mv bin / "idle", bin / "idle-2.4"
    mv bin / "pydoc", bin / "pydoc-2.4"
    mv bin / "smtpd.py", bin / "smtpd-2.4.py"

    # Add the Homebrew prefix path to site-packages via a .pth
    prefix_site_packages.mkpath
    (site_packages/"homebrew.pth").write prefix_site_packages

    package_build_args = []
    package_install_args = [
      "--prefix=#{prefix}",
      "--exec-prefix=#{prefix}",
      "--install-scripts=#{bin}",
    ]
    mkdir_p buildpath / "setuptools"
    mkdir_p buildpath / "pip"

    resource("pip").unpack(buildpath / "pip")
    resource("setuptools").unpack(buildpath / "setuptools")

    cd buildpath / "setuptools" do
      system bin / "python2.4", "setup.py", "build", *package_build_args
      ["_markerlib", "easy_install.py", "pkg_resources.py", "setuptools"].each do |item|
        mv buildpath / "setuptools" / "build" / "lib" / item, site_packages / item
      end
    end
    cd buildpath / "pip" do
      system bin / "python2.4", "setup.py", "build", *package_build_args
      system bin / "python2.4", "setup.py", "install", *package_install_args
    end

    (bin / "pip-2.4").write(<<EOF
#!/usr/bin/env python2.4 -u -x

from pip import main

if __name__ == "__main__":
    main()

EOF
)
    chmod 0o660, bin / "pip-2.4"
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
    system bin / "python2.4", "--help"
    system bin / "python2.4", "-c", "import unicodedata"
  end
end
__END__
diff --git a/Makefile.pre.in b/Makefile.pre.in
index d125bf6..9f1fde5 100644
--- a/Makefile.pre.in
+++ b/Makefile.pre.in
@@ -375,15 +375,18 @@ $(PYTHONFRAMEWORKDIR)/Versions/$(VERSION)/$(PYTHONFRAMEWORK): \
                 $(RESSRCDIR)/English.lproj/InfoPlist.strings
 	$(INSTALL) -d -m $(DIRMODE) $(PYTHONFRAMEWORKDIR)/Versions/$(VERSION)
 	if test "${UNIVERSALSDK}"; then \
-		$(CC) -o $(LDLIBRARY) -arch i386 -arch ppc -dynamiclib \
+		$(CC) -o $(LDLIBRARY) -arch i386 -arch arm64 -dynamiclib \
 			-isysroot "${UNIVERSALSDK}" \
 			-all_load $(LIBRARY) -Wl,-single_module \
 			-install_name $(DESTDIR)$(PYTHONFRAMEWORKINSTALLDIR)/Versions/$(VERSION)/Python \
 			-compatibility_version $(VERSION) \
 			-current_version $(VERSION); \
         else \
-		libtool -o $(LDLIBRARY) -dynamic $(OTHER_LIBTOOL_OPT) $(LIBRARY) \
-			@LIBTOOL_CRUFT@ ;\
+		$(CC) -o $(LDLIBRARY) -dynamiclib \
+			-all_load $(LIBRARY) -Wl,-single_module \
+			-install_name $(DESTDIR)$(PYTHONFRAMEWORKINSTALLDIR)/Versions/$(VERSION)/Python \
+			-compatibility_version $(VERSION) \
+			-current_version $(VERSION); \
 	fi
 	$(INSTALL) -d -m $(DIRMODE)  \
 		$(PYTHONFRAMEWORKDIR)/Versions/$(VERSION)/Resources/English.lproj
diff --git a/Modules/_ssl.c b/Modules/_ssl.c
index f90ec13..5ba83c0 100644
--- a/Modules/_ssl.c
+++ b/Modules/_ssl.c
@@ -33,13 +33,13 @@ enum py_ssl_error {
 #endif
 
 /* Include OpenSSL header files */
-#include "openssl/rsa.h"
-#include "openssl/crypto.h"
-#include "openssl/x509.h"
-#include "openssl/pem.h"
-#include "openssl/ssl.h"
-#include "openssl/err.h"
-#include "openssl/rand.h"
+#include <openssl/rsa.h>
+#include <openssl/crypto.h>
+#include <openssl/x509.h>
+#include <openssl/pem.h>
+#include <openssl/ssl.h>
+#include <openssl/err.h>
+#include <openssl/rand.h>
 
 /* SSL error object */
 static PyObject *PySSLErrorObject;
@@ -55,6 +55,10 @@ static PyObject *PySSLErrorObject;
 # undef HAVE_OPENSSL_RAND
 #endif
 
+#ifdef __APPLE__
+extern int RAND_egd(const char *path);
+#endif
+
 typedef struct {
 	PyObject_HEAD
 	PySocketSockObject *Socket;	/* Socket on which we're layered */
@@ -290,7 +294,7 @@ newPySSLObject(PySocketSockObject *Sock, char *key_file, char *cert_file)
 		PySSL_SetError(self, ret);
 		goto fail;
 	}
-	self->ssl->debug = 1;
+	// self->ssl->debug = 1;
 
 	Py_BEGIN_ALLOW_THREADS
 	if ((self->server_cert = SSL_get_peer_certificate(self->ssl))) {
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
index 4d19c34..43a4d91 100644
--- a/Modules/getaddrinfo.c
+++ b/Modules/getaddrinfo.c
@@ -57,6 +57,16 @@
 #include "addrinfo.h"
 #endif
 
+#include <netinet/in.h>
+#include <arpa/inet.h>
+
+typedef unsigned short u_short;
+typedef unsigned long u_long;
+typedef unsigned char u_char;
+
+extern const char *hstrerror(int err);
+extern int inet_aton(const char *cp, struct in_addr *pin);
+
 #if defined(__KAME__) && defined(ENABLE_IPV6)
 # define FAITH
 #endif
diff --git a/Modules/posixmodule.c b/Modules/posixmodule.c
index dc7f723..ce6c501 100644
--- a/Modules/posixmodule.c
+++ b/Modules/posixmodule.c
@@ -23,6 +23,12 @@
 #  pragma weak statvfs
 #  pragma weak fstatvfs
 
+#include <sys/param.h>
+#include <unistd.h>
+
+#include <sys/types.h>
+#include <sys/disk.h>
+
 #endif /* __APPLE__ */
 
 #include "Python.h"
@@ -155,6 +161,9 @@ corresponding Unix manual entries for more information on calls.");
    (default) */
 extern char        *ctermid_r(char *);
 #endif
+extern int getloadavg(double[], int);
+extern char *ctermid_r(char *buf);
+extern int setgroups(int ngroups, const gid_t *gidset);
 
 #ifndef HAVE_UNISTD_H
 #if defined(PYCC_VACPP)
diff --git a/Modules/readline.c b/Modules/readline.c
index 5094bf2..7e8f51c 100644
--- a/Modules/readline.c
+++ b/Modules/readline.c
@@ -708,12 +708,12 @@ setup_readline(void)
 	rl_bind_key_in_map ('\t', rl_complete, emacs_meta_keymap);
 	rl_bind_key_in_map ('\033', rl_complete, emacs_meta_keymap);
 	/* Set our hook functions */
-	rl_startup_hook = (Function *)on_startup_hook;
+	rl_startup_hook = (void *)on_startup_hook;
 #ifdef HAVE_RL_PRE_INPUT_HOOK
-	rl_pre_input_hook = (Function *)on_pre_input_hook;
+	rl_pre_input_hook = (void *)on_pre_input_hook;
 #endif
 	/* Set our completion function */
-	rl_attempted_completion_function = (CPPFunction *)flex_complete;
+	rl_attempted_completion_function = (void *)flex_complete;
 	/* Set Python word break characters */
 	rl_completer_word_break_characters =
 		strdup(" \t\n`~!@#$%^&*()-=+[{]}\\|;:'\",<>/?");
