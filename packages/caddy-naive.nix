{
  caddy,
  fetchurl,
  lib,
}:

(caddy.withPlugins {
  plugins = [
    "github.com/caddyserver/forwardproxy=github.com/klzgrad/forwardproxy@v0.0.0-20261022172731-e747854e7874"
  ];
  hash = lib.fakeHash;
}).overrideAttrs
  (old: {
    # The Naïve fork needs this upstream backport for Caddy 2.11's idle timeouts.
    postPatch = (old.postPatch or "") + ''
      patch -d vendor/github.com/caddyserver/caddy/v2 -p1 < ${
        fetchurl {
          url = "https://raw.githubusercontent.com/klzgrad/forwardproxy/e747854e78743dba85c039b38ed185fb11d93667/caddy-read-idle-timeout.patch";
          hash = "sha256-Alg/NkN06UYc7puVQ0m4fgOQ1gAxm+r89S68xeKUfqs=";
        }
      }
    '';
  })
