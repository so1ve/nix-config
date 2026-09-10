{
  ray.features."software/wemeet" = {
    home =
      { pkgs, ... }:
      let
        wemeet = pkgs.wemeet.overrideAttrs (old: {
          # Tencent's CDN rejects curl's default User-Agent with HTTP 403.
          src = old.src.overrideAttrs (src: {
            curlOptsList = src.curlOptsList ++ [
              "--user-agent"
              "Mozilla/5.0"
            ];
          });
        });
      in
      {
        home.packages = [ wemeet ];

        # Native Wayland entry failed to render shared screen video correctly.
        # Use XWayland instead
        xdg.desktopEntries.wemeetapp = {
          name = "WemeetApp";
          exec = "${wemeet}/bin/wemeet-xwayland %u";
          icon = "wemeet";
          terminal = false;
          categories = [ "AudioVideo" ];
          mimeType = [ "x-scheme-handler/wemeet" ];
          settings."Name[zh_CN]" = "腾讯会议";
        };
      };
  };
}
