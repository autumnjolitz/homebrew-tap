class ZopeAT211 < Formula
  desc "Zope 2.11"
  homepage "https://zopefoundation.github.io"
  url "https://zopefoundation.github.io/Zope/pre-egg-releases/Zope-2.11.8-final.tgz"
  sha256 "98eabf472d2b59ef99f9d0798a0ece10748fb4cd1226cc470ffbb84ff0b84e16"
  license "ZPL-2.1"

  keg_only "Zope binaries use the argv[0] for discovery, making symlinks of python scripts unreliable"

  depends_on "autumnjolitz/tap/python@24"

  resource "post-install" do
    url "https://raw.githubusercontent.com/autumnjolitz/homebrew-tap/refs/heads/main/patches/zope211.patch"
    sha256 "3296d45a51a2376ae1e17abb1a8055fc3ab1be1b2c501ff8a050d8f055dde75a"
  end

  def install
    mkdir_p buildpath / "obj"
    args = [
      "--prefix=#{prefix}",
      "--with-python=#{HOMEBREW_PREFIX}/opt/python@24/bin/python2.4",
      "--build-base=#{buildpath}/obj",
    ]
    system "./configure", *args
    system "make"
    system "make", "install"

    mkdir_p buildpath / "post-install"
    resource("post-install").unpack(buildpath / "post-install")
    patch_args = [
      "-d",
      prefix.to_s,
      "-p1",
      "-i",
      buildpath / "post-install" / "zope211.patch"
    ]

    system "patch", *patch_args

    chmod 0655, bin / "reindex_catalog.py"
    rm bin / "README.txt"
    rm bin / "python"

    Dir.entries bin.to_s |file|
      mv bin / file, libexec / "bin" / file
      (prefix, suffix) = file.split(".")
      prefixed_file = "#{prefix}-2.11.#{suffix}"
      (bin / prefixed_file).write <<~SHELL
        #!/usr/bin/env sh

        exec #{libexec}/bin/#{file} $@
      SHELL
      chmod 0655, bin / prefixed_file
    end
  end

  test do
    system "#{bin}/mkzopeinstance.py", "-d", "#{testpath}/zope", "-u", "admin:admin", "-s", "#{prefix}/skel"
    system "./zope/bin/zopectl", "test"
  end
end
