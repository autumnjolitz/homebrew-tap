class ZopeAT211 < Formula
  desc "Zope 2.11"
  homepage "https://zopefoundation.github.io"
  url "https://zopefoundation.github.io/Zope/pre-egg-releases/Zope-2.11.8-final.tgz"
  sha256 "98eabf472d2b59ef99f9d0798a0ece10748fb4cd1226cc470ffbb84ff0b84e16"
  license "ZPL-2.1"

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
      buildpath / "post-install" / "zope211.patch",
    ]

    system "patch", *patch_args

    mkdir_p libexec / "Zope"
    ln_s prefix / "skel", libexec / "skel"

    Dir.entries(bin.to_s).reject { |f| File.directory?(f) }.each do |file|
      mv bin / file, libexec / "Zope" / file
      (prefix, suffix) = file.split(".")
      prefixed_file = "#{prefix}-2.11.#{suffix}"
      (bin / prefixed_file).write <<~SHELL
        #!/usr/bin/env sh

        export SOFTWARE_HOME="${SOFTWARE_HOME:-#{lib}/python}"
        export ZOPE_HOME="${ZOPE_HOME:-#{opt_prefix}}"

        exec #{libexec}/Zope/#{file} "$@"
      SHELL
      chmod 0555, bin / prefixed_file
      chmod 0555, "#{libexec}/Zope/#{file}"
    end
  end

  test do
    system "#{bin}/mkzopeinstance.py", "-d", "#{testpath}/zope", "-u", "admin:admin", "-s", "#{prefix}/skel"
    system "./zope/bin/zopectl", "test"
  end
end
