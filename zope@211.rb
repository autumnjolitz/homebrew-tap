class ZopeAT211 < Formula
  desc "Zope 2.11"
  homepage "https://zopefoundation.github.io"
  url "https://zopefoundation.github.io/Zope/pre-egg-releases/Zope-2.11.8-final.tgz"
  sha256 "98eabf472d2b59ef99f9d0798a0ece10748fb4cd1226cc470ffbb84ff0b84e16"
  license "ZPL-2.1"

  depends_on "autumnjolitz/tap/python@24"

  patch :p1, :DATA

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
