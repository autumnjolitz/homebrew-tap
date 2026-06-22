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

    args = ["--prefix=#{prefix}", "--disable-toolbox-glue"]

    if build.with? "universal"
      args << "--enable-universalsdk=/"
      args << "--with-universal-archs=intel"
    end

    if build.with? "framework"
      args << "--enable-framework=#{frameworks}"
    elsif build.without? "static"
      args << "--enable-shared"
    end

    system "./configure", *args
    system "make"
    ENV.deparallelize # Some kinds of installs must be serialized.
    system "make", "install"

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
diff --git a/Modules/posixmodule.c b/Modules/posixmodule.c
index dc7f723..c941309 100644
--- a/Modules/posixmodule.c
+++ b/Modules/posixmodule.c
@@ -155,6 +155,7 @@ corresponding Unix manual entries for more information on calls.");
    (default) */
 extern char        *ctermid_r(char *);
 #endif
+extern int getloadavg(double[], int);
 
 #ifndef HAVE_UNISTD_H
 #if defined(PYCC_VACPP)
