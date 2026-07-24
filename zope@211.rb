class ZopeAT211 < Formula
  desc "Zope 2.11"
  homepage "https://zopefoundation.github.io"
  license "ZPL-2.1"

  head "https://codeberg.org/autumnlicious/Zope2.git", branch: "Zope211"

  stable do
    url "https://old.zope.dev/Products/Zope/2.11.8/Zope-2.11.8-final.tgz"
    sha256 "cdae1f71f8164901bec15d53a11cbedd17731dbb3c00963665a2aaebc44cad26"

    patch :p1, :DATA
  end

  bottle do
    root_url "https://ghcr.io/v2/autumnjolitz/tap"
    rebuild 2
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "f68c75c89aa6fc1a9aeaae4d3c72a136b3aa8bbd6f5111bb1ea50754ea04066e"
    sha256 cellar: :any,                 x86_64_linux: "8c3fa98c8764adab7edbf0dd78b40d73d64250bdab882ec1233933c6cdb4e1de"
  end

  depends_on "python@24"

  resource "apache" do
    url "https://www.apache.org/dyn/closer.lua?path=httpd/httpd-2.4.68.tar.bz2"
    sha256 "68c74d4df38c26bed4dfbdb8f3baf1eb532f3872357becc1bba5d136f6b63c06"
  end

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
  end

  test do
    system "#{libexec}/Zope/bin/mkzopeinstance.py", "-d", "#{testpath}/zope", "-u", "admin:admin"
  end
end
__END__
diff --git a/README.txt b/README.txt
index cdaad98..24cc3df 100644
--- a/README.txt
+++ b/README.txt
@@ -1,3 +1,34 @@
+==================================
+Zope 2.11.3+
+==================================
+
+This repository encompasses patches necessary towards running
+Zope 2 on docker, modern osx, et al.
+
+New Features:
+
+- ZServer/HTTP (``medusa``) supports ``bind_to`` keyword for overriding the actual ``socket.bind(...)`` value
+- zope.conf for the http server has a new directive: ``bind-to ADDRESS``
+
+   - ``ADDRESS`` may be one of the following:
+
+      * ip:port
+      * Path for UNIX Domain Socket
+
+Fixed Bugs:
+
+- TAL engine throws TypeError on XML/HTML fragments
+
+Known Bugs:
+
+- Unix Domain Sockets don't remove stale socket files
+- CGI server is broken for serving file streams
+
+GETs on an image for example returns:::
+
+    <open file 'Zope.jpg', mode 'r' at 0x140020378>
+
+
 Welcome to The Zope Source Release
 ==================================
 
diff --git a/lib/python/RestrictedPython/Guards.py b/lib/python/RestrictedPython/Guards.py
index 3ea59dc..6063dc2 100644
--- a/lib/python/RestrictedPython/Guards.py
+++ b/lib/python/RestrictedPython/Guards.py
@@ -24,7 +24,7 @@ for name in ['False', 'None', 'True', 'abs', 'basestring', 'bool', 'callable',
              'chr', 'cmp', 'complex', 'divmod', 'float', 'hash',
              'hex', 'id', 'int', 'isinstance', 'issubclass', 'len',
              'long', 'oct', 'ord', 'pow', 'range', 'repr', 'round',
-             'str', 'tuple', 'unichr', 'unicode', 'xrange', 'zip']:
+             'str', 'tuple', 'unichr', 'unicode', 'xrange', 'zip', 'set', 'frozenset']:
 
     safe_builtins[name] = __builtins__[name]
 
diff --git a/lib/python/ZServer/HTTPServer.py b/lib/python/ZServer/HTTPServer.py
index c1cb0ac..e7832d9 100644
--- a/lib/python/ZServer/HTTPServer.py
+++ b/lib/python/ZServer/HTTPServer.py
@@ -201,8 +201,9 @@ class zhttp_handler:
         if query:
             env['QUERY_STRING'] = query
         env['GATEWAY_INTERFACE']='CGI/1.1'
-        env['REMOTE_ADDR']=request.channel.addr[0]
-
+        env["REMOTE_ADDR"] = "127.0.0.1"
+        if request.channel.addr:
+            env['REMOTE_ADDR']=request.channel.addr[0]
 
         # This is a really bad hack to support WebDAV
         # clients accessing documents through GET
@@ -428,15 +429,18 @@ class zhttp_server(http_server):
     shutup=0
 
     def __init__ (self, ip, port, resolver=None, logger_object=None,
-                  fast_listen=True):
+                  fast_listen=True, family=None, bind_address=None, server_name=None):
         self.shutup=1
         self.fast_listen = fast_listen
-        http_server.__init__(self, ip, port, resolver, logger_object)
+        http_server.__init__(self, ip, port, resolver, logger_object,
+                             family, bind_address, server_name)
         self.shutup=0
         self.log_info('%s server started at %s\n'
+                      '\tAddress: %s\n'
                       '\tHostname: %s\n\tPort: %d' % (
             self.server_protocol,
             time.ctime(time.time()),
+            self._address,
             self.server_name,
             self.server_port
             ))
diff --git a/lib/python/ZServer/component.xml b/lib/python/ZServer/component.xml
index e83a1e9..d42481b 100644
--- a/lib/python/ZServer/component.xml
+++ b/lib/python/ZServer/component.xml
@@ -12,6 +12,16 @@
                datatype=".HTTPServerFactory"
                implements="ZServer.server">
      <key name="address" datatype="inet-binding-address"/>
+     <key name="server-name" datatype="string">
+      <description>
+        Override the SERVER_NAME.
+      </description>
+     </key>
+     <key name="bind-to" datatype="socket-address">
+      <description>
+        Bind to another host:port or even a unix domain socket path.
+      </description>
+     </key>
      <key name="force-connection-close" datatype="boolean" default="off"/>
      <key name="webdav-source-clients">
        <description>
@@ -25,7 +35,11 @@
          immediately or only after Zope is ready to run.
        </description>
      </key>
-     <key name="use-wsgi" datatype="boolean" default="off" />
+     <key name="use-wsgi" datatype="boolean" default="off">
+      <description>
+        Speak WSGI protocol or not.
+      </description>
+     </key>
   </sectiontype>
 
   <sectiontype name="webdav-source-server"
diff --git a/lib/python/ZServer/datatypes.py b/lib/python/ZServer/datatypes.py
index 00b19de..118f387 100644
--- a/lib/python/ZServer/datatypes.py
+++ b/lib/python/ZServer/datatypes.py
@@ -66,6 +66,14 @@ class HTTPServerFactory(ServerFactory):
                 "No 'address' settings found "
                 "within the 'http-server' or 'webdav-source-server' section")
         ServerFactory.__init__(self, section.address)
+        self.bind_address = None
+        self.family = None
+        self.server_name = None
+        if section.bind_to:
+            self.family = section.bind_to.family
+            self.bind_address = section.bind_to.address
+        if section.server_name:
+            self.server_name = section.server_name
         self.server_class = HTTPServer.zhttp_server
         self.force_connection_close = section.force_connection_close
         # webdav-source-server sections won't have webdav_source_clients:
@@ -83,7 +91,9 @@ class HTTPServerFactory(ServerFactory):
         server = self.server_class(ip=self.ip, port=self.port,
                                    resolver=self.dnsresolver,
                                    fast_listen=self.fast_listen,
-                                   logger_object=access_logger)
+                                   logger_object=access_logger,
+                                   family=self.family, bind_address=self.bind_address,
+                                   server_name=self.server_name)
         server.install_handler(handler)
         return server
 
diff --git a/lib/python/ZServer/medusa/http_server.py b/lib/python/ZServer/medusa/http_server.py
index c442597..4f3a8d0 100644
--- a/lib/python/ZServer/medusa/http_server.py
+++ b/lib/python/ZServer/medusa/http_server.py
@@ -286,9 +286,11 @@ class http_request:
                     name = 'Unknown (bad auth string)'
                 else:
                     name = t[0]
-
+        remote_host = "127.0.0.1"
+        if self.channel.addr:
+            remote_host = self.channel.addr[0]
         self.channel.server.logger.log (
-            self.channel.addr[0],
+            remote_host,
             '- %s [%s] "%s" %d %d "%s" "%s"\n' % (
                 name,
                 self.log_date_string (time.time()),
@@ -558,11 +560,14 @@ class http_server (asyncore.dispatcher):
     
     channel_class = http_channel
     
-    def __init__ (self, ip, port, resolver=None, logger_object=None):
+    def __init__ (self, ip, port, resolver=None, logger_object=None,
+                  family=None, bind_address=None, server_name=None):
         self.ip = ip
         self.port = port
         asyncore.dispatcher.__init__ (self)
-        self.create_socket (socket.AF_INET, socket.SOCK_STREAM)
+        if family is None:
+            family = socket.AF_INET
+        self.create_socket (family, socket.SOCK_STREAM)
         
         self.handlers = []
         
@@ -570,24 +575,31 @@ class http_server (asyncore.dispatcher):
             logger_object = logger.file_logger (sys.stdout)
             
         self.set_reuse_addr()
-        self.bind ((ip, port))
-        
+        if bind_address is None:
+            bind_address = (ip, port)
+        self.bind (bind_address)
         # lower this to 5 if your OS complains
         self.listen (1024)
-        
-        host, port = self.socket.getsockname()
-        if not ip:
-            self.log_info('Computing default hostname', 'warning')
+        if family == socket.AF_INET:
+            host, port = self.socket.getsockname()
+            self._address = "tcp://%s:%s" % (host, port)
+        elif family == socket.AF_UNIX:
+            port = -1
+            self._address = "unix://%s" % (self.socket.getsockname(),)
+        else:
+            raise ValueError('Unsupported type!')
+        if not server_name:
+            if not ip:
+                self.log_info('Computing default hostname', 'warning')
+                try:
+                    ip = socket.gethostbyname(socket.gethostname())
+                except socket.error:
+                    ip = socket.gethostbyname('localhost')
             try:
-                ip = socket.gethostbyname(socket.gethostname())
+                self.server_name = socket.gethostbyaddr (ip)[0]
             except socket.error:
-                ip = socket.gethostbyname('localhost')
-        try:
-            self.server_name = socket.gethostbyaddr (ip)[0]
-        except socket.error:
-            self.log_info('Cannot do reverse lookup', 'warning')
-            self.server_name = ip       # use the IP address as the "hostname"
-            
+                self.log_info('Cannot do reverse lookup', 'warning')
+                self.server_name = ip       # use the IP address as the "hostname"
         self.server_port = port
         self.total_clients = counter()
         self.total_requests = counter()
@@ -605,11 +617,13 @@ class http_server (asyncore.dispatcher):
             
         self.log_info (
                 'Medusa (V%s) started at %s'
+                '\n\tAddress: %s'
                 '\n\tHostname: %s'
                 '\n\tPort:%d'
                 '\n' % (
                         VERSION_STRING,
                         time.ctime(time.time()),
+                        self._address,
                         self.server_name,
                         port,
                         )
diff --git a/lib/python/zope/tal/talinterpreter.py b/lib/python/zope/tal/talinterpreter.py
index 1e23a44..8980db3 100644
--- a/lib/python/zope/tal/talinterpreter.py
+++ b/lib/python/zope/tal/talinterpreter.py
@@ -781,7 +781,8 @@ class TALInterpreter(object):
 
     def insertHTMLStructure(self, text, repldict):
         from zope.tal.htmltalparser import HTMLTALParser
-        gen = AltTALGenerator(repldict, self.engine, 0)
+        engine = self.engine._engine
+        gen = AltTALGenerator(repldict, engine, 0)
         p = HTMLTALParser(gen) # Raises an exception if text is invalid
         p.parseString(text)
         program, macros = p.getCode()
@@ -789,7 +790,8 @@ class TALInterpreter(object):
 
     def insertXMLStructure(self, text, repldict):
         from zope.tal.talparser import TALParser
-        gen = AltTALGenerator(repldict, self.engine, 0)
+        engine = self.engine._engine
+        gen = AltTALGenerator(repldict, engine, 0)
         p = TALParser(gen)
         gen.enable(0)
         p.parseFragment('<!DOCTYPE foo PUBLIC "foo" "bar"><foo>')
diff --git a/skel/bin/runzope.in b/skel/bin/runzope.in
index b1f3ae5..3955b8a 100755
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
+INSTANCE_HOME="${ZOPE_INSTANCE_HOME:-$(dirname "$(dirname "$(readlink -f -- "$0")")")}"
+CONFIG_FILE="${ZOPE_CONFIG_FILE:-${INSTANCE_HOME}/etc/zope.conf}"
+SOFTWARE_HOME="${ZOPE_SOFTWARE_HOME:-<<SOFTWARE_HOME>>}"
+PYTHONPATH="$SOFTWARE_HOME:${PYTHONPATH:-}"
+
 export PYTHONPATH INSTANCE_HOME SOFTWARE_HOME
 
 ZOPE_RUN="$SOFTWARE_HOME/Zope2/Startup/run.py"
 
-exec "$PYTHON" "$ZOPE_RUN" -C "$CONFIG_FILE" "$@"
+exec "$ZOPE_PYTHON" "$ZOPE_RUN" -C "$CONFIG_FILE" "$@"
diff --git a/skel/bin/zopectl.in b/skel/bin/zopectl.in
index ca9e379..daab8f6 100755
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
+INSTANCE_HOME="${ZOPE_INSTANCE_HOME:-$(dirname "$(dirname "$(readlink -f -- "$0")")")}"
+CONFIG_FILE="${ZOPE_CONFIG_FILE:-${INSTANCE_HOME}/etc/zope.conf}"
+SOFTWARE_HOME="${ZOPE_SOFTWARE_HOME:-<<SOFTWARE_HOME>>}"
+PYTHONPATH="$SOFTWARE_HOME:${PYTHONPATH:-}"
+
 export PYTHONPATH INSTANCE_HOME SOFTWARE_HOME
 
 ZDCTL="$SOFTWARE_HOME/Zope2/Startup/zopectl.py"
 
-exec "$PYTHON" "$ZDCTL" -C "$CONFIG_FILE" "$@"
+exec "$ZOPE_PYTHON" "$ZDCTL" -C "$CONFIG_FILE" "$@"
diff --git a/skel/etc/zope.conf.in b/skel/etc/zope.conf.in
index 8962d76..6070752 100644
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
@@ -962,11 +976,14 @@ instancehome $INSTANCE
 #
 # Default:
 #
-#     An HTTP server starts on port 8080.
+#     An HTTP server starts on port localhost:8100.
 
 <http-server>
   # valid keys are "address" and "force-connection-close"
-  address 8080
+  address localhost:8100
+
+  # This will instead serve off of the local var/server.sock:
+  # bind-to $INSTANCE/var/server.sock
 
   # force-connection-close on
   #
@@ -975,9 +992,18 @@ instancehome $INSTANCE
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
