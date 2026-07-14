class PythonAT27 < Formula
  desc "Interpreted, interactive, object-oriented programming language"
  homepage "https://www.python.org/"
  url "https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tar.xz"
  sha256 "b62c0e7937551d0cc02b8fd5cb0f544f9405bafc9a54d3808ed4594812edef43"
  revision 1
  head "https://github.com/python/cpython.git", :branch => "2.7"

  # setuptools remembers the build flags python is built with and uses them to
  # build packages later. Xcode-only systems need different flags.
  pour_bottle? do
    reason <<~EOS
      The bottle needs the Apple Command Line Tools to be installed.
        You can install them, if desired, with:
          xcode-select --install
    EOS
    satisfy { MacOS::CLT.installed? }
  end

  depends_on "pkg-config" => :build
  depends_on "gdbm"
  depends_on "openssl@3"
  depends_on "readline"
  depends_on "sqlite"

  resource "setuptools" do
    url "https://files.pythonhosted.org/packages/b2/40/4e00501c204b457f10fe410da0c97537214b2265247bc9a5bc6edd55b9e4/setuptools-44.1.1.zip"
    sha256 "c67aa55db532a0dadc4d2e20ba9961cbd3ccc84d544e9029699822542b5a476b"
  end

  resource "pip" do
    url "https://files.pythonhosted.org/packages/53/7f/55721ad0501a9076dbc354cc8c63ffc2d6f1ef360f49ad0fbcce19d68538/pip-20.3.4.tar.gz"
    sha256 "6773934e5f5fc3eaa8c5a44949b5b924fc122daa0a8aa9f80c835b4ca2a543fc"
  end

  resource "wheel" do
    url "https://files.pythonhosted.org/packages/c0/6c/9f840c2e55b67b90745af06a540964b73589256cb10cc10057c87ac78fc2/wheel-0.37.1.tar.gz"
    sha256 "e9a504e793efbca1b8e0e9cb979a249cf4a0a7b5b8c9e8b65a5e39d49529c1c4"
  end

  patch :p1, :DATA

  def lib_cellar
    prefix/"Frameworks/Python.framework/Versions/2.7/lib/python2.7"
  end

  def site_packages_cellar
    lib_cellar/"site-packages"
  end

  # The HOMEBREW_PREFIX location of site-packages.
  def site_packages
    HOMEBREW_PREFIX/"lib/python2.7/site-packages"
  end

  def install
    # Unset these so that installing pip and setuptools puts them where we want
    # and not into some other Python the user has installed.
    ENV["PYTHONHOME"] = nil
    ENV["PYTHONPATH"] = nil

    args = %W[
      --prefix=#{prefix}
      --enable-ipv6
      --datarootdir=#{share}
      --datadir=#{share}
      --mandir=#{man}
      --enable-framework=#{frameworks}
      --without-ensurepip
    ]

    # See upstream bug report from 22 Jan 2018 "Significant performance problems
    # with Python 2.7 built with clang 3.x or 4.x"
    # https://bugs.python.org/issue32616
    # https://github.com/Homebrew/homebrew-core/issues/22743
    if DevelopmentTools.clang_build_version >= 802 &&
       DevelopmentTools.clang_build_version < 902
      args << "--without-computed-gotos"
    end

    args << "--without-gcc" if ENV.compiler == :clang

    cflags   = []
    ldflags  = []
    cppflags = []

    unless MacOS.sdk_path.nil?
      # Help Python's build system (setuptools/pip) to build things on SDK-based systems
      # The setup.py looks at "-isysroot" to get the sysroot (and not at --sysroot)
      cflags  << "-isysroot #{MacOS.sdk_path}" << "-I#{MacOS.sdk_path}/usr/include"
      ldflags << "-isysroot #{MacOS.sdk_path}"
      # For the Xlib.h, Python needs this header dir with the system Tk
      # Yep, this needs the absolute path where zlib needed a path relative
      # to the SDK.
      cflags  << "-I#{MacOS.sdk_path}/System/Library/Frameworks/Tk.framework/Versions/8.5/Headers"
    end

    # Avoid linking to libgcc https://code.activestate.com/lists/python-dev/112195/
    args << "MACOSX_DEPLOYMENT_TARGET=#{MacOS.version}"

    # We want our readline and openssl! This is just to outsmart the detection code,
    # superenv handles that cc finds includes/libs!
    inreplace "setup.py" do |s|
      s.gsub! "do_readline = self.compiler.find_library_file(lib_dirs, 'readline')",
              "do_readline = '#{Formula["readline"].opt_lib}/libhistory.dylib'"
      s.gsub! "/usr/local/ssl", Formula["openssl@3"].opt_prefix
    end

    inreplace "setup.py" do |s|
      s.gsub! "sqlite_setup_debug = False", "sqlite_setup_debug = True"
      s.gsub! "for d_ in inc_dirs + sqlite_inc_paths:",
              "for d_ in ['#{Formula["sqlite"].opt_include}']:"

      # Allow sqlite3 module to load extensions:
      # https://docs.python.org/library/sqlite3.html#f1
      s.gsub! 'sqlite_defines.append(("SQLITE_OMIT_LOAD_EXTENSION", "1"))', ""
    end

    # Allow python modules to use ctypes.find_library to find homebrew's stuff
    # even if homebrew is not a /usr/local/lib. Try this with:
    # `brew install enchant && pip install pyenchant`
    inreplace "./Lib/ctypes/macholib/dyld.py" do |f|
      f.gsub! "DEFAULT_LIBRARY_FALLBACK = [", "DEFAULT_LIBRARY_FALLBACK = [ '#{HOMEBREW_PREFIX}/lib',"
      f.gsub! "DEFAULT_FRAMEWORK_FALLBACK = [", "DEFAULT_FRAMEWORK_FALLBACK = [ '#{HOMEBREW_PREFIX}/Frameworks',"
    end

    args << "CFLAGS=#{cflags.join(" ")}" unless cflags.empty?
    args << "LDFLAGS=#{ldflags.join(" ")}" unless ldflags.empty?
    args << "CPPFLAGS=#{cppflags.join(" ")}" unless cppflags.empty?

    system "./configure", *args
    system "make"

    ENV.deparallelize do
      # Tell Python not to install into /Applications
      system "make", "install", "PYTHONAPPSDIR=#{prefix}"
      system "make", "frameworkinstallextras", "PYTHONAPPSDIR=#{pkgshare}"
    end

    rm man / "man1/python.1"

    # Fixes setting Python build flags for certain software
    # See: https://github.com/Homebrew/homebrew/pull/20182
    # https://bugs.python.org/issue3588
    inreplace lib_cellar/"config/Makefile" do |s|
      s.change_make_var! "LINKFORSHARED",
        "-u _PyMac_Error $(PYTHONFRAMEWORKINSTALLDIR)/Versions/$(VERSION)/$(PYTHONFRAMEWORK)"
    end

    # Prevent third-party packages from building against fragile Cellar paths
    inreplace [lib_cellar/"_sysconfigdata.py",
               lib_cellar/"config/Makefile",
               frameworks/"Python.framework/Versions/Current/lib/pkgconfig/python-2.7.pc"],
              prefix, opt_prefix

    # Symlink the pkgconfig files into HOMEBREW_PREFIX so they're accessible.
    (lib/"pkgconfig").install_symlink Dir[frameworks/"Python.framework/Versions/Current/lib/pkgconfig/*"]

    # Remove 2to3 because Python 3 also installs it
    rm bin/"2to3"

    # A fix, because python and python@2 both want to install Python.framework
    # and therefore we can't link both into HOMEBREW_PREFIX/Frameworks
    # https://github.com/Homebrew/homebrew/issues/15943
    ["Headers", "Python", "Resources"].each { |f| rm(prefix/"Frameworks/Python.framework/#{f}") }
    rm prefix/"Frameworks/Python.framework/Versions/Current"

    # Remove the site-packages that Python created in its Cellar.
    site_packages_cellar.rmtree

    (libexec/"setuptools").install resource("setuptools")
    (libexec/"pip").install resource("pip")
    (libexec/"wheel").install resource("wheel")
  end

  def post_install
    # Avoid conflicts with lingering unversioned files from Python 3
    rm_f %W[
      #{HOMEBREW_PREFIX}/bin/easy_install
      #{HOMEBREW_PREFIX}/bin/pip
      #{HOMEBREW_PREFIX}/bin/wheel
    ]

    # Fix up the site-packages so that user-installed Python software survives
    # minor updates, such as going from 2.7.0 to 2.7.1:

    # Create a site-packages in HOMEBREW_PREFIX/lib/python2.7/site-packages
    site_packages.mkpath

    # Symlink the prefix site-packages into the cellar.
    site_packages_cellar.unlink if site_packages_cellar.exist?
    site_packages_cellar.parent.install_symlink site_packages

    # Write our sitecustomize.py
    rm_rf Dir["#{site_packages}/sitecustomize.py[co]"]
    (site_packages/"sitecustomize.py").atomic_write(sitecustomize)

    # Remove old setuptools installations that may still fly around and be
    # listed in the easy_install.pth. This can break setuptools build with
    # zipimport.ZipImportError: bad local file header
    # setuptools-0.9.5-py3.3.egg
    rm_rf Dir["#{site_packages}/setuptools*"]
    rm_rf Dir["#{site_packages}/distribute*"]
    rm_rf Dir["#{site_packages}/pip[-_.][0-9]*", "#{site_packages}/pip"]

    setup_args = ["-s", "setup.py", "--no-user-cfg", "install", "--force",
                  "--verbose",
                  "--single-version-externally-managed",
                  "--record=installed.txt",
                  "--install-scripts=#{bin}",
                  "--install-lib=#{site_packages}"]

    (libexec/"setuptools").cd { system "#{bin}/python", *setup_args }
    (libexec/"pip").cd { system "#{bin}/python", *setup_args }
    (libexec/"wheel").cd { system "#{bin}/python", *setup_args }

    # When building from source, these symlinks will not exist, since
    # post_install happens after linking.
    %w[pip pip2 pip2.7 easy_install easy_install-2.7 wheel].each do |e|
      (HOMEBREW_PREFIX/"bin").install_symlink bin/e
    end

    # Help distutils find brewed stuff when building extensions
    include_dirs = [HOMEBREW_PREFIX/"include", Formula["openssl@3"].opt_include,
                    Formula["sqlite"].opt_include]
    library_dirs = [HOMEBREW_PREFIX/"lib", Formula["openssl@3"].opt_lib,
                    Formula["sqlite"].opt_lib]

    cfg = lib_cellar/"distutils/distutils.cfg"
    cfg.atomic_write <<~EOS
      [install]
      prefix=#{HOMEBREW_PREFIX}

      [build_ext]
      include_dirs=#{include_dirs.join ":"}
      library_dirs=#{library_dirs.join ":"}
    EOS
  end

  def sitecustomize
    <<~EOS
      # This file is created by Homebrew and is executed on each python startup.
      # Don't print from here, or else python command line scripts may fail!
      # <https://docs.brew.sh/Homebrew-and-Python>
      import re
      import os
      import sys

      if sys.version_info[0] != 2:
          # This can only happen if the user has set the PYTHONPATH for 3.x and run Python 2.x or vice versa.
          # Every Python looks at the PYTHONPATH variable and we can't fix it here in sitecustomize.py,
          # because the PYTHONPATH is evaluated after the sitecustomize.py. Many modules (e.g. PyQt4) are
          # built only for a specific version of Python and will fail with cryptic error messages.
          # In the end this means: Don't set the PYTHONPATH permanently if you use different Python versions.
          exit('Your PYTHONPATH points to a site-packages dir for Python 2.x but you are running Python ' +
               str(sys.version_info[0]) + '.x!\\n     PYTHONPATH is currently: "' + str(os.environ['PYTHONPATH']) + '"\\n' +
               '     You should `unset PYTHONPATH` to fix this.')

      # Only do this for a brewed python:
      if os.path.realpath(sys.executable).startswith('#{rack}'):
          # Shuffle /Library site-packages to the end of sys.path and reject
          # paths in /System pre-emptively (#14712)
          library_site = '/Library/Python/2.7/site-packages'
          library_packages = [p for p in sys.path if p.startswith(library_site)]
          sys.path = [p for p in sys.path if not p.startswith(library_site) and
                                             not p.startswith('/System')]
          # .pth files have already been processed so don't use addsitedir
          sys.path.extend(library_packages)

          # the Cellar site-packages is a symlink to the HOMEBREW_PREFIX
          # site_packages; prefer the shorter paths
          long_prefix = re.compile(r'#{rack}/[0-9\._abrc]+/Frameworks/Python\.framework/Versions/2\.7/lib/python2\.7/site-packages')
          sys.path = [long_prefix.sub('#{site_packages}', p) for p in sys.path]

          # LINKFORSHARED (and python-config --ldflags) return the
          # full path to the lib (yes, "Python" is actually the lib, not a
          # dir) so that third-party software does not need to add the
          # -F/#{HOMEBREW_PREFIX}/Frameworks switch.
          try:
              from _sysconfigdata import build_time_vars
              build_time_vars['LINKFORSHARED'] = '-u _PyMac_Error #{opt_prefix}/Frameworks/Python.framework/Versions/2.7/Python'
          except:
              pass  # remember: don't print here. Better to fail silently.

          # Set the sys.executable to use the opt_prefix
          sys.executable = '#{opt_bin}/python2.7'
    EOS
  end

  def caveats; <<~EOS
    Pip and setuptools have been installed. To update them
      pip install --upgrade pip setuptools

    You can install Python packages with
      pip install <package>

    They will install into the site-package directory
      #{site_packages}

    See: https://docs.brew.sh/Homebrew-and-Python
  EOS
  end

  test do
    # Check if sqlite is ok, because we build with --enable-loadable-sqlite-extensions
    # and it can occur that building sqlite silently fails if OSX's sqlite is used.
    system "#{bin}/python", "-c", "import sqlite3"
    # Check if some other modules import. Then the linked libs are working.
    system "#{bin}/python", "-c", "import Tkinter; root = Tkinter.Tk()"
    system "#{bin}/python", "-c", "import gdbm"
    system "#{bin}/python", "-c", "import zlib"
    system bin/"pip", "list", "--format=columns"
  end
end
__END__
diff --git a/Lib/_osx_support.py b/Lib/_osx_support.py
index d2aaae7..55d698c 100644
--- a/Lib/_osx_support.py
+++ b/Lib/_osx_support.py
@@ -437,6 +437,9 @@ def get_platform_osx(_config_vars, osname, release, machine):
     # MACOSX_DEPLOYMENT_TARGET.
 
     macver = _config_vars.get('MACOSX_DEPLOYMENT_TARGET', '')
+    if not isinstance(macver, str):
+        macver = str(macver)
+        _config_vars["MACOSX_DEPLOYMENT_TARGET"] = macver
     macrelease = _get_system_version() or macver
     macver = macver or macrelease
 
@@ -476,7 +479,7 @@ def get_platform_osx(_config_vars, osname, release, machine):
                 machine = 'intel'
             elif archs == ('i386', 'ppc', 'x86_64'):
                 machine = 'fat3'
-            elif archs == ('ppc64', 'x86_64'):
+            elif archs == ('arm64', 'x86_64'):
                 machine = 'fat64'
             elif archs == ('i386', 'ppc', 'ppc64', 'x86_64'):
                 machine = 'universal'
diff --git a/Lib/distutils/spawn.py b/Lib/distutils/spawn.py
index 737b293..5e3621d 100644
--- a/Lib/distutils/spawn.py
+++ b/Lib/distutils/spawn.py
@@ -126,13 +126,13 @@ def _spawn_posix(cmd, search_path=1, verbose=0, dry_run=0):
             _cfg_target = sysconfig.get_config_var(
                                   'MACOSX_DEPLOYMENT_TARGET') or ''
             if _cfg_target:
-                _cfg_target_split = [int(x) for x in _cfg_target.split('.')]
+                _cfg_target_split = [int(x) for x in str(_cfg_target).split('.')]
         if _cfg_target:
             # ensure that the deployment target of build process is not less
             # than that used when the interpreter was built. This ensures
             # extension modules are built with correct compatibility values
             cur_target = os.environ.get('MACOSX_DEPLOYMENT_TARGET', _cfg_target)
-            if _cfg_target_split > [int(x) for x in cur_target.split('.')]:
+            if _cfg_target_split > [int(x) for x in str(cur_target).split('.')]:
                 my_msg = ('$MACOSX_DEPLOYMENT_TARGET mismatch: '
                           'now "%s" but "%s" during configure'
                                 % (cur_target, _cfg_target))
diff --git a/Mac/Tools/pythonw.c b/Mac/Tools/pythonw.c
index 76734c1..b0cf723 100644
--- a/Mac/Tools/pythonw.c
+++ b/Mac/Tools/pythonw.c
@@ -111,6 +111,9 @@ setup_spawnattr(posix_spawnattr_t* spawnattr)
 #if defined(__ppc64__)
     cpu_types[0] = CPU_TYPE_POWERPC64;
 
+#elif defined(__arm64__)
+    cpu_types[0] = CPU_TYPE_ARM64;
+
 #elif defined(__x86_64__)
     cpu_types[0] = CPU_TYPE_X86_64;
 
diff --git a/Modules/_ctypes/libffi_osx/include/ffi.h b/Modules/_ctypes/libffi_osx/include/ffi.h
index c104a5c..373557e 100644
--- a/Modules/_ctypes/libffi_osx/include/ffi.h
+++ b/Modules/_ctypes/libffi_osx/include/ffi.h
@@ -61,6 +61,8 @@ extern "C" {
 #		define X86_DARWIN
 #	elif defined(__ppc__) || defined(__ppc64__)
 #		define POWERPC_DARWIN
+#	elif defined(__arm64__)
+#		define AARCH64
 #	else
 #	error "Unsupported MacOS X CPU type"
 #	endif
diff --git a/Modules/_ctypes/libffi_osx/include/fficonfig.h b/Modules/_ctypes/libffi_osx/include/fficonfig.h
index 2172490..d722bd5 100644
--- a/Modules/_ctypes/libffi_osx/include/fficonfig.h
+++ b/Modules/_ctypes/libffi_osx/include/fficonfig.h
@@ -46,6 +46,13 @@
 #	define	SIZEOF_DOUBLE 8
 #	define	HAVE_LONG_DOUBLE 1
 #	define	SIZEOF_LONG_DOUBLE 16
+#elif defined(__arm64__)
+#	define	BYTEORDER 1234
+#	undef	HOST_WORDS_BIG_ENDIAN
+#	undef	WORDS_BIGENDIAN
+#	define	SIZEOF_DOUBLE 8
+#	define	HAVE_LONG_DOUBLE 1
+#	define	SIZEOF_LONG_DOUBLE 16
 
 #else
 #error "Unknown CPU type"
diff --git a/Modules/_ctypes/libffi_osx/include/ffitarget.h b/Modules/_ctypes/libffi_osx/include/ffitarget.h
index faaa30d..6ec1ff4 100644
--- a/Modules/_ctypes/libffi_osx/include/ffitarget.h
+++ b/Modules/_ctypes/libffi_osx/include/ffitarget.h
@@ -8,6 +8,8 @@
 #include "x86-ffitarget.h"
 #elif defined(__ppc__) || defined(__ppc64__)
 #include "ppc-ffitarget.h"
+#elif defined(__arm64__)
+#include "aarch64-ffitarget.h"
 #else
 #error "Unsupported CPU type"
 #endif
\ No newline at end of file
diff --git a/README b/README
index 4afaac0..63bc66d 100644
--- a/README
+++ b/README
@@ -1,3 +1,9 @@
+Build Python2.framework for Arm64 and x86_64 on macOS
+
+./configure --without-gcc --with-framework-name=Python2 \
+            --enable-unicode=ucs4 --enable-ipv6 --enable-toolbox-glue --enable-optimizations \
+            --enable-framework --enable-universalsdk --with-universal-archs=64-bit
+
 This is Python version 2.7.18
 =============================
 
diff --git a/configure b/configure
index 63d6753..3c6d1ab 100755
--- a/configure
+++ b/configure
@@ -6128,7 +6128,7 @@ $as_echo "$CC" >&6; }
                ARCH_RUN_32BIT=""
                ;;
             64-bit)
-               UNIVERSAL_ARCH_FLAGS="-arch ppc64 -arch x86_64"
+               UNIVERSAL_ARCH_FLAGS="-arch arm64 -arch x86_64"
                LIPO_32BIT_FLAGS=""
                ARCH_RUN_32BIT=""
                ;;
@@ -8471,8 +8471,8 @@ fi
     	i386)
     		MACOSX_DEFAULT_ARCH="x86_64"
     		;;
-    	ppc)
-    		MACOSX_DEFAULT_ARCH="ppc64"
+    	arm64)
+    		MACOSX_DEFAULT_ARCH="arm64"
     		;;
     	*)
     		as_fn_error $? "Unexpected output of 'arch' on OSX" "$LINENO" 5
diff --git a/configure.ac b/configure.ac
index efe6922..d943e8b 100644
--- a/configure.ac
+++ b/configure.ac
@@ -52,7 +52,7 @@ dnl can cause trouble.
 dnl Last slash shouldn't be stripped if prefix=/
 if test "$prefix" != "/"; then
     prefix=`echo "$prefix" | sed -e 's/\/$//g'`
-fi    
+fi
 
 dnl This is for stuff that absolutely must end up in pyconfig.h.
 dnl Please use pyport.h instead, if possible.
@@ -210,7 +210,7 @@ AC_ARG_ENABLE(framework,
               AS_HELP_STRING([--enable-framework@<:@=INSTALLDIR@:>@], [Build (MacOSX|Darwin) framework]),
 [
 	case $enableval in
-	yes) 
+	yes)
 		enableval=/Library/Frameworks
 	esac
 	case $enableval in
@@ -265,7 +265,7 @@ AC_ARG_ENABLE(framework,
 			FRAMEWORKINSTALLAPPSPREFIX="${MDIR}/Applications"
 
 			if test "${prefix}" = "NONE"; then
-				# User hasn't specified the 
+				# User hasn't specified the
 				# --prefix option, but wants to install
 				# the framework in a non-default location,
 				# ensure that the compatibility links get
@@ -393,7 +393,7 @@ if test "$cross_compiling" = yes; then
 	esac
 	_PYTHON_HOST_PLATFORM="$MACHDEP${_host_cpu:+-$_host_cpu}"
 fi
-	
+
 # Some systems cannot stand _XOPEN_SOURCE being defined at all; they
 # disable features if it is defined, without any means to access these
 # features as extensions. For these systems, we skip the definition of
@@ -410,7 +410,7 @@ case $ac_sys_system/$ac_sys_release in
   # Reconfirmed for OpenBSD 3.3 by Zachary Hamm, for 3.4 by Jason Ish.
   # In addition, Stefan Krah confirms that issue #1244610 exists through
   # OpenBSD 4.6, but is fixed in 4.7.
-  OpenBSD/2.* | OpenBSD/3.* | OpenBSD/4.@<:@0123456@:>@) 
+  OpenBSD/2.* | OpenBSD/3.* | OpenBSD/4.@<:@0123456@:>@)
     define_xopen_source=no
     # OpenBSD undoes our definition of __BSD_VISIBLE if _XOPEN_SOURCE is
     # also defined. This can be overridden by defining _BSD_SOURCE
@@ -448,12 +448,12 @@ case $ac_sys_system/$ac_sys_release in
   # with _XOPEN_SOURCE and __BSD_VISIBLE does not re-enable them.
   FreeBSD/4.*)
     define_xopen_source=no;;
-  # On MacOS X 10.2, a bug in ncurses.h means that it craps out if 
+  # On MacOS X 10.2, a bug in ncurses.h means that it craps out if
   # _XOPEN_EXTENDED_SOURCE is defined. Apparently, this is fixed in 10.3, which
   # identifies itself as Darwin/7.*
   # On Mac OS X 10.4, defining _POSIX_C_SOURCE or _XOPEN_SOURCE
   # disables platform specific features beyond repair.
-  # On Mac OS X 10.3, defining _POSIX_C_SOURCE or _XOPEN_SOURCE 
+  # On Mac OS X 10.3, defining _POSIX_C_SOURCE or _XOPEN_SOURCE
   # has no effect, don't bother defining them
   Darwin/@<:@6789@:>@.*)
     define_xopen_source=no;;
@@ -479,7 +479,7 @@ esac
 
 if test $define_xopen_source = yes
 then
-  AC_DEFINE(_XOPEN_SOURCE, 600, 
+  AC_DEFINE(_XOPEN_SOURCE, 600,
             Define to the level of X/Open that your system supports)
 
   # On Tru64 Unix 4.0F, defining _XOPEN_SOURCE also requires
@@ -490,7 +490,7 @@ then
    	    Define to activate Unix95-and-earlier features)
 
   AC_DEFINE(_POSIX_C_SOURCE, 200112L, Define to activate features from IEEE Stds 1003.1-2001)
-  
+
 fi
 
 #
@@ -521,11 +521,11 @@ AC_MSG_CHECKING(EXTRAPLATDIR)
 if test -z "$EXTRAPLATDIR"
 then
 	case $MACHDEP in
-	darwin)	
+	darwin)
 		EXTRAPLATDIR="\$(PLATMACDIRS)"
 		EXTRAMACHDEPPATH="\$(PLATMACPATH)"
 		;;
-	*) 
+	*)
 		EXTRAPLATDIR=""
 		EXTRAMACHDEPPATH=""
 		;;
@@ -663,7 +663,7 @@ AC_ARG_WITH(cxx_main,
             AS_HELP_STRING([--with-cxx-main=<compiler>],
                            [compile main() and link python executable with C++ compiler]),
 [
-	
+
 	case $withval in
 	no)	with_cxx_main=no
 		MAINCC='$(CC)';;
@@ -790,7 +790,7 @@ AC_MSG_RESULT($LIBRARY)
 # systems without shared libraries, LDLIBRARY is the same as LIBRARY
 # (defined in the Makefiles). On Cygwin LDLIBRARY is the import library,
 # DLLLIBRARY is the shared (i.e., DLL) library.
-# 
+#
 # RUNSHARED is used to run shared python without installed libraries
 #
 # INSTSONAME is the name of the shared library that will be use to install
@@ -812,7 +812,7 @@ RUNSHARED=''
 # If CXX is set, and if it is needed to link a main function that was
 # compiled with CXX, LINKCC is CXX instead. Always using CXX is undesirable:
 # python might then depend on the C++ runtime
-# This is altered for AIX in order to build the export list before 
+# This is altered for AIX in order to build the export list before
 # linking.
 AC_SUBST(LINKCC)
 AC_MSG_CHECKING(LINKCC)
@@ -859,7 +859,7 @@ AC_ARG_ENABLE(shared,
               AS_HELP_STRING([--enable-shared], [disable/enable building shared python library]))
 
 if test -z "$enable_shared"
-then 
+then
   case $ac_sys_system in
   CYGWIN* | atheos*)
     enable_shared="yes";;
@@ -904,7 +904,7 @@ then
   BLDLIBRARY=''
 else
   BLDLIBRARY='$(LDLIBRARY)'
-fi  
+fi
 
 # Other platforms follow
 if test $enable_shared = "yes"; then
@@ -1038,14 +1038,14 @@ fi
 
 # Check for --with-pydebug
 AC_MSG_CHECKING(for --with-pydebug)
-AC_ARG_WITH(pydebug, 
+AC_ARG_WITH(pydebug,
             AS_HELP_STRING([--with-pydebug], [build with Py_DEBUG defined]),
 [
 if test "$withval" != no
-then 
-  AC_DEFINE(Py_DEBUG, 1, 
-  [Define if you want to build an interpreter with many run-time checks.]) 
-  AC_MSG_RESULT(yes); 
+then
+  AC_DEFINE(Py_DEBUG, 1,
+  [Define if you want to build an interpreter with many run-time checks.])
+  AC_MSG_RESULT(yes);
   Py_DEBUG='true'
 else AC_MSG_RESULT(no); Py_DEBUG='false'
 fi],
@@ -1179,7 +1179,7 @@ yes)
                ARCH_RUN_32BIT=""
                ;;
             64-bit)
-               UNIVERSAL_ARCH_FLAGS="-arch ppc64 -arch x86_64"
+               UNIVERSAL_ARCH_FLAGS="-arch arm64 -arch x86_64"
                LIPO_32BIT_FLAGS=""
                ARCH_RUN_32BIT=""
                ;;
@@ -1589,7 +1589,7 @@ int main(){
 AC_MSG_RESULT($ac_cv_pthread_is_default)
 
 
-if test $ac_cv_pthread_is_default = yes 
+if test $ac_cv_pthread_is_default = yes
 then
   ac_cv_kpthread=no
 else
@@ -1688,14 +1688,14 @@ ac_save_cxx="$CXX"
 
 if test "$ac_cv_kpthread" = "yes"
 then
-  CXX="$CXX -Kpthread"  
+  CXX="$CXX -Kpthread"
   ac_cv_cxx_thread=yes
 elif test "$ac_cv_kthread" = "yes"
 then
   CXX="$CXX -Kthread"
   ac_cv_cxx_thread=yes
 elif test "$ac_cv_pthread" = "yes"
-then 
+then
   CXX="$CXX -pthread"
   ac_cv_cxx_thread=yes
 fi
@@ -1814,11 +1814,11 @@ if test "$use_lfs" = "yes"; then
 # These may affect some typedefs
 case $ac_sys_system/$ac_sys_release in
 AIX*)
-    AC_DEFINE(_LARGE_FILES, 1, 
+    AC_DEFINE(_LARGE_FILES, 1,
     [This must be defined on AIX systems to enable large file support.])
     ;;
 esac
-AC_DEFINE(_LARGEFILE_SOURCE, 1, 
+AC_DEFINE(_LARGEFILE_SOURCE, 1,
 [This must be defined on some systems to enable large file support.])
 AC_DEFINE(_FILE_OFFSET_BITS, 64,
 [This must be set to 64 on some systems to enable large file support.])
@@ -1880,7 +1880,7 @@ AC_CHECK_SIZEOF(pid_t, 4)
 AC_MSG_CHECKING(for long long support)
 have_long_long=no
 AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[]], [[long long x; x = (long long)0;]])],[
-  AC_DEFINE(HAVE_LONG_LONG, 1, [Define this if you have the type long long.]) 
+  AC_DEFINE(HAVE_LONG_LONG, 1, [Define this if you have the type long long.])
   have_long_long=yes
 ],[])
 AC_MSG_RESULT($have_long_long)
@@ -1902,7 +1902,7 @@ fi
 AC_MSG_CHECKING(for _Bool support)
 have_c99_bool=no
 AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[]], [[_Bool x; x = (_Bool)0;]])],[
-  AC_DEFINE(HAVE_C99_BOOL, 1, [Define this if you have the type _Bool.]) 
+  AC_DEFINE(HAVE_C99_BOOL, 1, [Define this if you have the type _Bool.])
   have_c99_bool=yes
 ],[])
 AC_MSG_RESULT($have_c99_bool)
@@ -1910,8 +1910,8 @@ if test "$have_c99_bool" = yes ; then
 AC_CHECK_SIZEOF(_Bool, 1)
 fi
 
-AC_CHECK_TYPES(uintptr_t, 
-   [AC_CHECK_SIZEOF(uintptr_t, 4)], 
+AC_CHECK_TYPES(uintptr_t,
+   [AC_CHECK_SIZEOF(uintptr_t, 4)],
    [], [#ifdef HAVE_STDINT_H
         #include <stdint.h>
         #endif
@@ -1930,7 +1930,7 @@ if test "$have_long_long" = yes
 then
 if test "$ac_cv_sizeof_off_t" -gt "$ac_cv_sizeof_long" -a \
 	"$ac_cv_sizeof_long_long" -ge "$ac_cv_sizeof_off_t"; then
-  AC_DEFINE(HAVE_LARGEFILE_SUPPORT, 1, 
+  AC_DEFINE(HAVE_LARGEFILE_SUPPORT, 1,
   [Defined to enable large file support when an off_t is bigger than a long
    and long long is available and at least as big as an off_t. You may need
    to add some flags for configuration and compilation to enable this mode.
@@ -1981,7 +1981,7 @@ AC_ARG_ENABLE(toolbox-glue,
               AS_HELP_STRING([--enable-toolbox-glue], [disable/enable MacOSX glue code for extensions]))
 
 if test -z "$enable_toolbox_glue"
-then 
+then
 	case $ac_sys_system/$ac_sys_release in
 	Darwin/*)
 		enable_toolbox_glue="yes";;
@@ -2006,7 +2006,7 @@ AC_MSG_RESULT($enable_toolbox_glue)
 
 AC_SUBST(OTHER_LIBTOOL_OPT)
 case $ac_sys_system/$ac_sys_release in
-  Darwin/@<:@01567@:>@\..*) 
+  Darwin/@<:@01567@:>@\..*)
     OTHER_LIBTOOL_OPT="-prebind -seg1addr 0x10000000"
     ;;
   Darwin/*)
@@ -2017,7 +2017,7 @@ esac
 
 AC_SUBST(LIBTOOL_CRUFT)
 case $ac_sys_system/$ac_sys_release in
-  Darwin/@<:@01567@:>@\..*) 
+  Darwin/@<:@01567@:>@\..*)
     LIBTOOL_CRUFT="-framework System -lcc_dynamic"
     if test "${enable_universalsdk}"; then
 	    :
@@ -2031,7 +2031,7 @@ case $ac_sys_system/$ac_sys_release in
     if test ${gcc_version} '<' 4.0
         then
             LIBTOOL_CRUFT="-lcc_dynamic"
-        else 
+        else
             LIBTOOL_CRUFT=""
     fi
     AC_RUN_IFELSE([AC_LANG_SOURCE([[
@@ -2045,14 +2045,14 @@ case $ac_sys_system/$ac_sys_release in
       }
     }
     ]])],[ac_osx_32bit=yes],[ac_osx_32bit=no],[ac_osx_32bit=yes])
-    
+
     if test "${ac_osx_32bit}" = "yes"; then
     	case `/usr/bin/arch` in
-    	i386) 
-    		MACOSX_DEFAULT_ARCH="i386" 
+    	i386)
+    		MACOSX_DEFAULT_ARCH="i386"
     		;;
-    	ppc) 
-    		MACOSX_DEFAULT_ARCH="ppc" 
+    	ppc)
+    		MACOSX_DEFAULT_ARCH="ppc"
     		;;
     	*)
     		AC_MSG_ERROR([Unexpected output of 'arch' on OSX])
@@ -2060,11 +2060,11 @@ case $ac_sys_system/$ac_sys_release in
     	esac
     else
     	case `/usr/bin/arch` in
-    	i386) 
-    		MACOSX_DEFAULT_ARCH="x86_64" 
+    	i386)
+    		MACOSX_DEFAULT_ARCH="x86_64"
     		;;
-    	ppc) 
-    		MACOSX_DEFAULT_ARCH="ppc64" 
+    	arm64)
+    		MACOSX_DEFAULT_ARCH="arm64"
     		;;
     	*)
     		AC_MSG_ERROR([Unexpected output of 'arch' on OSX])
@@ -2082,9 +2082,9 @@ AC_MSG_CHECKING(for --enable-framework)
 if test "$enable_framework"
 then
 	BASECFLAGS="$BASECFLAGS -fno-common -dynamic"
-	# -F. is needed to allow linking to the framework while 
+	# -F. is needed to allow linking to the framework while
 	# in the build location.
-	AC_DEFINE(WITH_NEXT_FRAMEWORK, 1, 
+	AC_DEFINE(WITH_NEXT_FRAMEWORK, 1,
          [Define if you want to produce an OpenStep/Rhapsody framework
          (shared library plus accessory files).])
 	AC_MSG_RESULT(yes)
@@ -2099,7 +2099,7 @@ fi
 AC_MSG_CHECKING(for dyld)
 case $ac_sys_system/$ac_sys_release in
   Darwin/*)
-  	AC_DEFINE(WITH_DYLD, 1, 
+  	AC_DEFINE(WITH_DYLD, 1,
         [Define if you want to use the new-style (Openstep, Rhapsody, MacOS)
          dynamic linker (dyld) instead of the old-style (NextStep) dynamic
          linker (rld). Dyld is necessary to support frameworks.])
@@ -2165,7 +2165,7 @@ then
 		;;
 	IRIX/5*) LDSHARED="ld -shared";;
 	IRIX*/6*) LDSHARED="ld ${SGI_ABI} -shared -all";;
-	SunOS/5*) 
+	SunOS/5*)
 		if test "$GCC" = "yes" ; then
 			LDSHARED='$(CC) -shared'
 			LDCXXSHARED='$(CXX) -shared'
@@ -2346,7 +2346,7 @@ then
 	BSD/OS/4*) LINKFORSHARED="-Xlinker -export-dynamic";;
 	Linux*|GNU*) LINKFORSHARED="-Xlinker -export-dynamic";;
 	# -u libsys_s pulls in all symbols in libsys
-	Darwin/*) 
+	Darwin/*)
 		# -u _PyMac_Error is needed to pull in the mac toolbox glue,
 		# which is
 		# not used by the core itself but which needs to be in the core so
@@ -2364,7 +2364,7 @@ then
 	OpenUNIX*|UnixWare*) LINKFORSHARED="-Wl,-Bexport";;
 	SCO_SV*) LINKFORSHARED="-Wl,-Bexport";;
 	ReliantUNIX*) LINKFORSHARED="-W1 -Blargedynsym";;
-	FreeBSD*|NetBSD*|OpenBSD*|DragonFly*) 
+	FreeBSD*|NetBSD*|OpenBSD*|DragonFly*)
 		if [[ "`$CC -dM -E - </dev/null | grep __ELF__`" != "" ]]
 		then
 			LINKFORSHARED="-Wl,--export-dynamic"
@@ -2624,7 +2624,7 @@ then
     # Defining _REENTRANT on system with POSIX threads should not hurt.
     AC_DEFINE(_REENTRANT)
     posix_threads=yes
-    THREADOBJ="Python/thread.o"    
+    THREADOBJ="Python/thread.o"
     if test "$ac_sys_system" = "SunOS"; then
         CFLAGS="$CFLAGS -D_REENTRANT"
     fi
@@ -2751,7 +2751,7 @@ pthread_create (NULL, NULL, start_routine, NULL)]])],[
     THREADOBJ="Python/thread.o"
     USE_THREAD_MODULE=""])
 
-    if test "$posix_threads" != "yes"; then     
+    if test "$posix_threads" != "yes"; then
       AC_CHECK_LIB(thread, thr_create, [AC_DEFINE(WITH_THREAD)
       LIBS="$LIBS -lthread"
       THREADOBJ="Python/thread.o"
@@ -2771,7 +2771,7 @@ fi
 if test "$posix_threads" = "yes"; then
       if test "$unistd_defines_pthreads" = "no"; then
          AC_DEFINE(_POSIX_THREADS, 1,
-         [Define if you have POSIX threads, 
+         [Define if you have POSIX threads,
           and your system does not define that.])
       fi
 
@@ -3016,9 +3016,9 @@ AC_MSG_CHECKING(for --with-tsc)
 AC_ARG_WITH(tsc,
 	    AS_HELP_STRING([--with(out)-tsc],[enable/disable timestamp counter profile]),[
 if test "$withval" != no
-then 
-  AC_DEFINE(WITH_TSC, 1, 
-    [Define to profile with the Pentium timestamp counter]) 
+then
+  AC_DEFINE(WITH_TSC, 1,
+    [Define to profile with the Pentium timestamp counter])
     AC_MSG_RESULT(yes)
 else AC_MSG_RESULT(no)
 fi],
@@ -3034,7 +3034,7 @@ then with_pymalloc="yes"
 fi
 if test "$with_pymalloc" != "no"
 then
-    AC_DEFINE(WITH_PYMALLOC, 1, 
+    AC_DEFINE(WITH_PYMALLOC, 1,
      [Define if you want to compile in Python-specific mallocs])
 fi
 AC_MSG_RESULT($with_pymalloc)
@@ -3054,14 +3054,14 @@ fi
 
 # Check for --with-wctype-functions
 AC_MSG_CHECKING(for --with-wctype-functions)
-AC_ARG_WITH(wctype-functions, 
+AC_ARG_WITH(wctype-functions,
             AS_HELP_STRING([--with-wctype-functions], [use wctype.h functions]),
 [
 if test "$withval" != no
-then 
+then
   AC_DEFINE(WANT_WCTYPE_FUNCTIONS, 1,
   [Define if you want wctype.h functions to be used instead of the
-   one supplied by Python itself. (see Include/unicodectype.h).]) 
+   one supplied by Python itself. (see Include/unicodectype.h).])
   AC_MSG_RESULT(yes)
 else AC_MSG_RESULT(no)
 fi],
@@ -3311,12 +3311,12 @@ dnl before searching for static libraries. setup.py adds -Wl,-search_paths_first
 dnl to revert to a more traditional unix behaviour and make it possible to
 dnl override the system libz with a local static library of libz. Temporarily
 dnl add that flag to our CFLAGS as well to ensure that we check the version
-dnl of libz that will be used by setup.py. 
-dnl The -L/usr/local/lib is needed as wel to get the same compilation 
+dnl of libz that will be used by setup.py.
+dnl The -L/usr/local/lib is needed as wel to get the same compilation
 dnl environment as setup.py (and leaving it out can cause configure to use the
 dnl wrong version of the library)
 case $ac_sys_system/$ac_sys_release in
-Darwin/*) 
+Darwin/*)
 	_CUR_CFLAGS="${CFLAGS}"
 	_CUR_LDFLAGS="${LDFLAGS}"
 	CFLAGS="${CFLAGS} -Wl,-search_paths_first"
@@ -3327,7 +3327,7 @@ esac
 AC_CHECK_LIB(z, inflateCopy, AC_DEFINE(HAVE_ZLIB_COPY, 1, [Define if the zlib library has inflateCopy]))
 
 case $ac_sys_system/$ac_sys_release in
-Darwin/*) 
+Darwin/*)
 	CFLAGS="${_CUR_CFLAGS}"
 	LDFLAGS="${_CUR_LDFLAGS}"
 	;;
@@ -3381,14 +3381,14 @@ AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
 
 # check for openpty and forkpty
 
-AC_CHECK_FUNCS(openpty,, 
+AC_CHECK_FUNCS(openpty,,
    AC_CHECK_LIB(util,openpty,
      [AC_DEFINE(HAVE_OPENPTY) LIBS="$LIBS -lutil"],
      AC_CHECK_LIB(bsd,openpty, [AC_DEFINE(HAVE_OPENPTY) LIBS="$LIBS -lbsd"])
    )
 )
-AC_CHECK_FUNCS(forkpty,, 
-   AC_CHECK_LIB(util,forkpty, 
+AC_CHECK_FUNCS(forkpty,,
+   AC_CHECK_LIB(util,forkpty,
      [AC_DEFINE(HAVE_FORKPTY) LIBS="$LIBS -lutil"],
      AC_CHECK_LIB(bsd,forkpty, [AC_DEFINE(HAVE_FORKPTY) LIBS="$LIBS -lbsd"])
    )
@@ -3401,7 +3401,7 @@ AC_CHECK_FUNCS(memmove)
 AC_CHECK_FUNCS(fseek64 fseeko fstatvfs ftell64 ftello statvfs)
 
 AC_REPLACE_FUNCS(dup2 getcwd strdup)
-AC_CHECK_FUNCS(getpgrp, 
+AC_CHECK_FUNCS(getpgrp,
   AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[#include <unistd.h>]], [[getpgrp(0);]])],
     [AC_DEFINE(GETPGRP_HAVE_ARG, 1, [Define if getpgrp() must be called as getpgrp(0).])],
     [])
@@ -3411,7 +3411,7 @@ AC_CHECK_FUNCS(setpgrp,
     [AC_DEFINE(SETPGRP_HAVE_ARG, 1, [Define if setpgrp() must be called as setpgrp(0, 0).])],
     [])
 )
-AC_CHECK_FUNCS(gettimeofday, 
+AC_CHECK_FUNCS(gettimeofday,
   AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[#include <sys/time.h>]],
   				     [[gettimeofday((struct timeval*)0,(struct timezone*)0);]])],
     [],
@@ -3441,7 +3441,7 @@ AC_LINK_IFELSE([AC_LANG_PROGRAM([[
 ])
 
 # On OSF/1 V5.1, getaddrinfo is available, but a define
-# for [no]getaddrinfo in netdb.h. 
+# for [no]getaddrinfo in netdb.h.
 AC_MSG_CHECKING(for getaddrinfo)
 AC_LINK_IFELSE([AC_LANG_PROGRAM([[
 #include <sys/types.h>
@@ -3603,7 +3603,7 @@ AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
 ]], [[;]])],[
   AC_DEFINE(SYS_SELECT_WITH_SYS_TIME, 1,
   [Define if  you can safely include both <sys/select.h> and <sys/time.h>
-   (which you can't on SCO ODT 3.0).]) 
+   (which you can't on SCO ODT 3.0).])
   was_it_defined=yes
 ],[])
 AC_MSG_RESULT($was_it_defined)
@@ -3654,8 +3654,8 @@ AC_MSG_RESULT($works)
 have_prototypes=no
 AC_MSG_CHECKING(for prototypes)
 AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[int foo(int x) { return 0; }]], [[return foo(10);]])],
-  [AC_DEFINE(HAVE_PROTOTYPES, 1, 
-     [Define if your compiler supports function prototype]) 
+  [AC_DEFINE(HAVE_PROTOTYPES, 1,
+     [Define if your compiler supports function prototype])
    have_prototypes=yes],
   []
 )
@@ -3676,7 +3676,7 @@ int foo(int x, ...) {
 ]], [[return foo(10, "", 3.14);]])],[
   AC_DEFINE(HAVE_STDARG_PROTOTYPES, 1,
    [Define if your compiler supports variable length function prototypes
-   (e.g. void fprintf(FILE *, char *, ...);) *and* <stdarg.h>]) 
+   (e.g. void fprintf(FILE *, char *, ...);) *and* <stdarg.h>])
   works=yes
 ],[])
 AC_MSG_RESULT($works)
@@ -3711,7 +3711,7 @@ AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
 #include <varargs.h>
 #endif
 ]], [[va_list list1, list2; list1 = list2;]])],[],[
- AC_DEFINE(VA_LIST_IS_ARRAY, 1, [Define if a va_list is an array of some kind]) 
+ AC_DEFINE(VA_LIST_IS_ARRAY, 1, [Define if a va_list is an array of some kind])
  va_list_is_array=yes
 ])
 AC_MSG_RESULT($va_list_is_array)
@@ -3806,9 +3806,9 @@ AC_ARG_WITH(fpectl,
             AS_HELP_STRING([--with-fpectl], [enable SIGFPE catching]),
 [
 if test "$withval" != no
-then 
+then
   AC_DEFINE(WANT_SIGFPE_HANDLER, 1,
-  [Define if you want SIGFPE handled (see Include/pyfpe.h).]) 
+  [Define if you want SIGFPE handled (see Include/pyfpe.h).])
   AC_MSG_RESULT(yes)
 else AC_MSG_RESULT(no)
 fi],
@@ -4123,8 +4123,8 @@ AC_DEFINE_UNQUOTED(PYLONG_BITS_IN_DIGIT, $enable_big_digits, [Define as the pref
 
 # check for wchar.h
 AC_CHECK_HEADER(wchar.h, [
-  AC_DEFINE(HAVE_WCHAR_H, 1, 
-  [Define if the compiler provides a wchar.h header file.]) 
+  AC_DEFINE(HAVE_WCHAR_H, 1,
+  [Define if the compiler provides a wchar.h header file.])
   wchar_h="yes"
 ],
 wchar_h="no"
@@ -4167,10 +4167,10 @@ then
   [ac_cv_wchar_t_signed=yes])])
   AC_MSG_RESULT($ac_cv_wchar_t_signed)
 fi
-  
+
 AC_MSG_CHECKING(what type to use for unicode)
 dnl quadrigraphs "@<:@" and "@:>@" produce "[" and "]" in the output
-AC_ARG_ENABLE(unicode, 
+AC_ARG_ENABLE(unicode,
               AS_HELP_STRING([--enable-unicode@<:@=ucs@<:@24@:>@@:>@], [Enable Unicode strings (default is ucs2)]),
               [],
               [enable_unicode=yes])
@@ -4442,7 +4442,7 @@ int main()
 	   tm->tm_zone does not exist since it is the alternative way
 	   of getting timezone info.
 
-	   Red Hat 6.2 doesn't understand the southern hemisphere 
+	   Red Hat 6.2 doesn't understand the southern hemisphere
 	   after New Year's Day.
 	*/
 
@@ -4455,7 +4455,7 @@ int main()
 	    exit(1);
 #if HAVE_TZNAME
 	/* For UTC, tzname[1] is sometimes "", sometimes "   " */
-	if (strcmp(tzname[0], "UTC") || 
+	if (strcmp(tzname[0], "UTC") ||
 		(tzname[1][0] != 0 && tzname[1][0] != ' '))
 	    exit(1);
 #endif
@@ -4580,7 +4580,7 @@ AC_MSG_RESULT($ac_cv_window_has_flags)
 
 if test "$ac_cv_window_has_flags" = yes
 then
-  AC_DEFINE(WINDOW_HAS_FLAGS, 1, 
+  AC_DEFINE(WINDOW_HAS_FLAGS, 1,
   [Define if WINDOW in curses.h offers a field _flags.])
 fi
 
@@ -4871,7 +4871,7 @@ for dir in $SRCDIRS; do
     fi
 done
 
-# BEGIN_COMPUTED_GOTO 
+# BEGIN_COMPUTED_GOTO
 # Check for --with-computed-gotos
 AC_MSG_CHECKING(for --with-computed-gotos)
 AC_ARG_WITH(computed-gotos,
@@ -4879,15 +4879,15 @@ AC_ARG_WITH(computed-gotos,
                            [Use computed gotos in evaluation loop (enabled by default on supported compilers)]),
 [
 if test "$withval" = yes
-then 
+then
   AC_DEFINE(USE_COMPUTED_GOTOS, 1,
-  [Define if you want to use computed gotos in ceval.c.]) 
+  [Define if you want to use computed gotos in ceval.c.])
   AC_MSG_RESULT(yes)
 fi
 if test "$withval" = no
-then 
+then
   AC_DEFINE(USE_COMPUTED_GOTOS, 0,
-  [Define if you want to use computed gotos in ceval.c.]) 
+  [Define if you want to use computed gotos in ceval.c.])
   AC_MSG_RESULT(no)
 fi
 ],
diff --git a/setup.py b/setup.py
index f764223..68a5514 100644
--- a/setup.py
+++ b/setup.py
@@ -801,8 +801,9 @@ class PyBuildExt(build_ext):
         if host_platform == 'darwin':
             os_release = int(os.uname()[2].split('.')[0])
             dep_target = sysconfig.get_config_var('MACOSX_DEPLOYMENT_TARGET')
+            dep_target = str(dep_target)
             if (dep_target and
-                    (tuple(int(n) for n in dep_target.split('.')[0:2])
+                    (tuple(int(n) for n in dep_target.split('.', 1)[0:2])
                         < (10, 5) ) ):
                 os_release = 8
             if os_release < 9:
