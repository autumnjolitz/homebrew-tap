class Zope211 < Formula
  desc "Zope 2.11"
  homepage "https://zopefoundation.github.io"
  url "https://zopefoundation.github.io/Zope/pre-egg-releases/Zope-2.11.8-final.tgz"
  sha256 "98eabf472d2b59ef99f9d0798a0ece10748fb4cd1226cc470ffbb84ff0b84e16"
  license "ZPL-2.1-or-later"

  depends_on "autumnjolitz/tap/python24"

  resource "zope211-rt-patch" do
    url "https://gist.githubusercontent.com/autumnjolitz/b49b0b33be1eeaedafaac7b6a5b09b5b/raw/15b42064e99f10d1c2ce5f85b586afae250fa97b/zope211.patch"
    sha256 "3296d45a51a2376ae1e17abb1a8055fc3ab1be1b2c501ff8a050d8f055dde75a"
  end

  def install
    system "./configure", "--prefix=#{prefix}", "--with-python=python2.4", "--build-base=#{buildpath}"
    system "make"
    system "make", "install"

    resource("zope211-rt-patch").stage do
        mv "zope211.patch", "#{prefix}/zope211.patch"
        system "patch", "-d", "#{prefix}", "-p1", "-i", "zope211.patch"
        rm "#{prefix}/zope211.patch"
    end
  end

  test do
    system "#{bin}/mkzopeinstance.py", "-d", "#{testpath}/zope", "-u", "admin:admin", "-s", "#{prefix}/skel"
    system "./zope/bin/zopectl", "test"
  end
end