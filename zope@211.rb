class ZopeAT211 < Formula
  desc "Zope 2.11"
  homepage "https://zopefoundation.github.io"
  url "https://old.zope.dev/Products/Zope/2.11.8/Zope-2.11.8-final.tgz"
  sha256 "cdae1f71f8164901bec15d53a11cbedd17731dbb3c00963665a2aaebc44cad26"
  license "ZPL-2.1"

  depends_on "python@24"

  resource "apache" do
    url "https://dlcdn.apache.org/httpd/httpd-2.4.68.tar.bz2"
    sha256 "68c74d4df38c26bed4dfbdb8f3baf1eb532f3872357becc1bba5d136f6b63c06"
  end

  patch :p1, :DATA

  def install
    mkdir_p buildpath / "obj"
    args = [
      "--prefix=#{libexec}/Zope",
      "--with-python=#{HOMEBREW_PREFIX}/opt/python@24/bin/python2.4",
      "--build-base=#{buildpath}/obj",
    ]
    system "./configure", *args
    system "make"
    system "make", "install"

    mv libexec / "Zope" / "bin" / "README.txt", libexec / "Zope" / "README.txt"
    ln_s libexec / "Zope" / "skel", prefix / "skel"
    apache = buildpath / "apache"
    mkdir_p apache
    resource("apache").unpack(apache)
    mv apache / "docs/conf/mime.types", prefix / "skel" / "etc" / "mime.types"

    Dir.entries(libexec / "Zope" / "bin").reject { |f| File.directory?(f) }.each do |file|
      (prefix, suffix) = file.split(".")
      if suffix.nil?
        proxied_bin = "#{prefix}-2.11"
      else
        proxied_bin = "#{prefix}-2.11.#{suffix}"
      end
      (bin / proxied_bin).write <<~SHELL
        #!/usr/bin/env sh
        exec #{libexec}/Zope/bin/#{file} "$@"
      SHELL
      chmod 0555, bin / proxied_bin
    end
  end

  test do
    system "#{libexec}/Zope/mkzopeinstance.py", "-d", "#{testpath}/zope", "-u", "admin:admin"
  end
end
__END__
diff --git a/lib/python/RestrictedPython/Guards.py b/lib/python/RestrictedPython/Guards.py
index bcb0aa2..04c659b 100644
--- a/lib/python/RestrictedPython/Guards.py
+++ b/lib/python/RestrictedPython/Guards.py
@@ -24,7 +24,7 @@ for name in ['False', 'None', 'True', 'abs', 'basestring', 'bool', 'callable',
              'chr', 'cmp', 'complex', 'divmod', 'float', 'hash',
              'hex', 'id', 'int', 'isinstance', 'issubclass', 'len',
              'long', 'oct', 'ord', 'pow', 'range', 'repr', 'round',
-             'str', 'tuple', 'unichr', 'unicode', 'xrange', 'zip']:
+             'str', 'tuple', 'unichr', 'unicode', 'xrange', 'zip', 'set', 'frozenset']:
 
     safe_builtins[name] = __builtins__[name]
 
diff --git a/lib/python/zope/tal/talinterpreter.py b/lib/python/zope/tal/talinterpreter.py
index 9e65be5..d725307 100644
--- a/lib/python/zope/tal/talinterpreter.py
+++ b/lib/python/zope/tal/talinterpreter.py
@@ -30,7 +30,6 @@ from zope.tal.taldefs import getProgramVersion, getProgramMode
 from zope.tal.talgenerator import TALGenerator
 from zope.tal.translationcontext import TranslationContext
 
-
 # Avoid constructing this tuple over and over
 I18nMessageTypes = (Message,)
 
@@ -781,7 +780,7 @@ class TALInterpreter(object):
 
     def insertHTMLStructure(self, text, repldict):
         from zope.tal.htmltalparser import HTMLTALParser
-        gen = AltTALGenerator(repldict, self.engine, 0)
+        gen = AltTALGenerator(repldict, self.engine._engine, 0)
         p = HTMLTALParser(gen) # Raises an exception if text is invalid
         p.parseString(text)
         program, macros = p.getCode()
@@ -789,7 +788,7 @@ class TALInterpreter(object):
 
     def insertXMLStructure(self, text, repldict):
         from zope.tal.talparser import TALParser
-        gen = AltTALGenerator(repldict, self.engine, 0)
+        gen = AltTALGenerator(repldict, self.engine._engine, 0)
         p = TALParser(gen)
         gen.enable(0)
         p.parseFragment('<!DOCTYPE foo PUBLIC "foo" "bar"><foo>')
