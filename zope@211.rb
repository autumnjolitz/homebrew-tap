class ZopeAT211 < Formula
  desc "Zope 2.11"
  homepage "https://zopefoundation.github.io"
  url "https://old.zope.dev/Products/Zope/2.11.8/Zope-2.11.8-final.tgz"
  sha256 "cdae1f71f8164901bec15d53a11cbedd17731dbb3c00963665a2aaebc44cad26"
  license "ZPL-2.1"

  depends_on "python@24"

  # resource "twisted" do
  #   url "https://files.pythonhosted.org/packages/f9/80/50b40d787ee26af3062eb83b9a57fa3bdb5e0417f6a3047fffdbd09de6d9/Twisted-10.2.0.tar.bz2"
  #   sha256 "562ed61c18aa72da99c23fb19c2c101d178995eb3a78ab3c09560a613e180c84"
  # end

  resource "apache" do
    url "https://www.apache.org/dyn/closer.lua?path=httpd/httpd-2.4.68.tar.bz2"
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
    skel = prefix / "skel"
    mv apache / "docs/conf/mime.types", skel / "etc" / "mime.types"

    Dir.entries(libexec / "Zope" / "bin").reject { |f| File.directory?(f) }.each do |file|
      (prefix, suffix) = file.split(".")
      proxied_bin = "#{prefix}-2.11"
      proxied_bin = "#{proxied_bin}.#{suffix}" unless suffix.nil?
      (bin / proxied_bin).write <<~SHELL
        #!/usr/bin/env sh
        exec #{libexec}/Zope/bin/#{file} "$@"
      SHELL
      chmod 0555, bin / proxied_bin
    end

    # mkdir_p buildpath / "twisted"
    # resource("twisted").unpack(buildpath / "twisted")
    # ENV["PYTHONPATH"] = libexec / "Zope" / "lib" / "python"
    # install_args = [
    #   "--install-lib",
    #   libexec / "Zope" / "lib" / "python",
    #   "--prefix",
    #   libexec / "Zope",
    #   "--single-version-externally-managed",
    #   "--record",
    #   "/dev/null",
    # ]
    # cd buildpath / "twisted" do
    #   system "python2.4", "setup.py", "build"
    #   system "python2.4", "setup.py", "install", *install_args
    # end
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
index 9e65be5..90d3806 100644
--- a/lib/python/zope/tal/talinterpreter.py
+++ b/lib/python/zope/tal/talinterpreter.py
@@ -781,7 +781,7 @@ class TALInterpreter(object):
 
     def insertHTMLStructure(self, text, repldict):
         from zope.tal.htmltalparser import HTMLTALParser
-        gen = AltTALGenerator(repldict, self.engine, 0)
+        gen = AltTALGenerator(repldict, self.engine._engine, 0)
         p = HTMLTALParser(gen) # Raises an exception if text is invalid
         p.parseString(text)
         program, macros = p.getCode()
@@ -789,7 +789,7 @@ class TALInterpreter(object):
 
     def insertXMLStructure(self, text, repldict):
         from zope.tal.talparser import TALParser
-        gen = AltTALGenerator(repldict, self.engine, 0)
+        gen = AltTALGenerator(repldict, self.engine._engine, 0)
         p = TALParser(gen)
         gen.enable(0)
         p.parseFragment('<!DOCTYPE foo PUBLIC "foo" "bar"><foo>')
diff --git a/skel/bin/runzope.in b/skel/bin/runzope.in
index 7cf7a69..daaedc2 100755
--- a/skel/bin/runzope.in
+++ b/skel/bin/runzope.in
@@ -1,13 +1,17 @@
-#! /bin/sh
-
-PYTHON="<<PYTHON>>"
-ZOPE_HOME="<<ZOPE_HOME>>"
-INSTANCE_HOME="<<INSTANCE_HOME>>"
-CONFIG_FILE="<<INSTANCE_HOME>>/etc/zope.conf"
-SOFTWARE_HOME="<<SOFTWARE_HOME>>"
-PYTHONPATH="$SOFTWARE_HOME:$PYTHONPATH"
+#!/usr/bin/env sh
+set -e
+set -u
+(set -o pipefail) && set -o pipefail
+
+ZOPE_PYTHON="${ZOPE_PYTHON:-<<PYTHON>>}"
+ZOPE_HOME="${ZOPE_HOME:-<<ZOPE_HOME>>}"
+INSTANCE_HOME="${ZOPE_INSTANCE_HOME:-<<INSTANCE_HOME>>}"
+CONFIG_FILE="${ZOPE_CONFIG_FILE:-<<INSTANCE_HOME>>/etc/zope.conf}"
+SOFTWARE_HOME="${ZOPE_SOFTWARE_HOME:-<<SOFTWARE_HOME>>}"
+PYTHONPATH="$SOFTWARE_HOME:${PYTHONPATH:-}"
+
 export PYTHONPATH INSTANCE_HOME SOFTWARE_HOME
 
 ZOPE_RUN="$SOFTWARE_HOME/Zope2/Startup/run.py"
 
-exec "$PYTHON" "$ZOPE_RUN" -C "$CONFIG_FILE" "$@"
+exec "$ZOPE_PYTHON" "$ZOPE_RUN" -C "$CONFIG_FILE" "$@"
diff --git a/skel/bin/zopectl.in b/skel/bin/zopectl.in
index 95aa933..6ad7540 100755
--- a/skel/bin/zopectl.in
+++ b/skel/bin/zopectl.in
@@ -1,13 +1,17 @@
-#! /bin/sh
-
-PYTHON="<<PYTHON>>"
-ZOPE_HOME="<<ZOPE_HOME>>"
-INSTANCE_HOME="<<INSTANCE_HOME>>"
-CONFIG_FILE="<<INSTANCE_HOME>>/etc/zope.conf"
-SOFTWARE_HOME="<<SOFTWARE_HOME>>"
-PYTHONPATH="$SOFTWARE_HOME:$PYTHONPATH"
+#!/usr/bin/env sh
+set -e
+set -u
+(set -o pipefail) && set -o pipefail
+
+ZOPE_PYTHON="${ZOPE_PYTHON:-<<PYTHON>>}"
+ZOPE_HOME="${ZOPE_HOME:-<<ZOPE_HOME>>}"
+INSTANCE_HOME="${ZOPE_INSTANCE_HOME:-<<INSTANCE_HOME>>}"
+CONFIG_FILE="${ZOPE_CONFIG_FILE:-<<INSTANCE_HOME>>/etc/zope.conf}"
+SOFTWARE_HOME="${ZOPE_SOFTWARE_HOME:-<<SOFTWARE_HOME>>}"
+PYTHONPATH="$SOFTWARE_HOME:${PYTHONPATH:-}"
+
 export PYTHONPATH INSTANCE_HOME SOFTWARE_HOME
 
 ZDCTL="$SOFTWARE_HOME/Zope2/Startup/zopectl.py"
 
-exec "$PYTHON" "$ZDCTL" -C "$CONFIG_FILE" "$@"
+exec "$ZOPE_PYTHON" "$ZDCTL" -C "$CONFIG_FILE" "$@"
diff --git a/skel/etc/zope.conf.in b/skel/etc/zope.conf.in
index f17bf6b..5a82b8d 100644
--- a/skel/etc/zope.conf.in
+++ b/skel/etc/zope.conf.in
@@ -214,7 +214,7 @@ instancehome $INSTANCE
 #
 # Example:
 #
-#    zserver-threads 10
+zserver-threads 32
 
 
 # Directive: python-check-interval
@@ -287,7 +287,7 @@ instancehome $INSTANCE
 # Example:
 #
 #     mime-types  $INSTANCE/etc/mime.types
-
+mime-types  $INSTANCE/etc/mime.types
 
 # Directive: structured-text-header-level
 #
@@ -315,6 +315,8 @@ instancehome $INSTANCE
 #
 #    rest-input-encoding iso-8859-15
 
+rest-input-encoding utf-8
+
 # Directive: rest-output-encoding
 #
 # Description:
@@ -328,6 +330,8 @@ instancehome $INSTANCE
 #
 #    rest-output-encoding iso-8859-15
 
+rest-output-encoding utf-8
+
 # Directive: rest-header-level
 #
 # Description:
@@ -403,6 +407,7 @@ instancehome $INSTANCE
 #
 #    ip-address 127.0.0.1
 
+ip-address 127.0.0.1
 
 # Directive: http-realm
 #
@@ -428,7 +433,7 @@ instancehome $INSTANCE
 # Example:
 #
 #    cgi-maxlen 10000
-
+cgi-maxlen 65535
 
 # Directive: http-header-max-length
 #
@@ -443,6 +448,8 @@ instancehome $INSTANCE
 #
 #     http-header-max-length 16384
 
+http-header-max-length 16384
+
 # Directive: enable-ms-author-via
 #
 # Description:
@@ -544,6 +551,8 @@ instancehome $INSTANCE
 #    trusted-proxy www.example.com
 #    trusted-proxy 192.168.1.1
 
+trusted-proxy 127.0.0.1
+
 # Directive: publisher-profile-file
 #
 # Description:
@@ -637,6 +646,8 @@ instancehome $INSTANCE
 #
 #    maximum-number-of-session-objects 10000
 
+maximum-number-of-session-objects 10000
+
 
 # Directive: session-add-notify-script-path
 #
@@ -898,7 +909,7 @@ instancehome $INSTANCE
 # Example:
 #
 #    max-listen-sockets 500
-
+max-listen-sockets 10000
 
 # Directives: port-base
 #
@@ -929,6 +940,7 @@ instancehome $INSTANCE
 # Example:
 #
 #    large-file-threshold 1Mb
+large-file-threshold 1Mb
 
 # Directive: default-zpublisher-encoding
 #
@@ -942,6 +954,8 @@ instancehome $INSTANCE
 #
 #    default-zpublisher-encoding utf-8
 
+default-zpublisher-encoding utf-8
+
 # Directives: servers
 #
 # Description:
@@ -962,12 +976,11 @@ instancehome $INSTANCE
 #
 # Default:
 #
-#     An HTTP server starts on port 8080.
+#     An HTTP server starts on port localhost:8100.
 
 <http-server>
   # valid keys are "address" and "force-connection-close"
-  address 8080
-
+  address localhost:8100
   # force-connection-close on
   #
   # You can also use the WSGI interface between ZServer and ZPublisher:
@@ -975,9 +988,18 @@ instancehome $INSTANCE
   #
   # To defer the opening of the HTTP socket until the end of the 
   # startup phase: 
-  # fast-listen off
+  fast-listen off
 </http-server>
 
+# ARJ: fastcgi is busted - tested with images and it returned 
+# the result of str(fh) lol
+# <fast-cgi>
+#     # valid key is "address"; the address may be hostname:port, port,
+#     # or a path for a Unix-domain socket
+#     address $INSTANCE/var/zope.sock
+# </fast-cgi>
+
+
 # Examples:
 #
 #  <ftp-server>
