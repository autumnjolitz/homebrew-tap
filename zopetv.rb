class ZopeTv < Formula
  desc "Zope TV"
  homepage "https://github.com/autumnjolitz/homebrew-tap"

  head do
    url "https://github.com/autumnjolitz/homebrew-tap.git", branch: "main"
  end

  license ""

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
  end

  test do
    system "#{bin}/mkzopeinstance.py", "-d", "#{testpath}/zope", "-u", "admin:admin", "-s", "#{prefix}/skel"
    system "./zope/bin/zopectl", "test"
  end
end
