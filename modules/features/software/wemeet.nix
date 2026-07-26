{
  ray.features."software/wemeet" = {
    home =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.wemeet ];

        # Native Wayland entry failed to render shared screen video correctly.
        # Use XWayland instead
        xdg.desktopEntries.wemeetapp = {
          name = "WemeetApp";
          exec = "${pkgs.wemeet}/bin/wemeet-xwayland %u";
          icon = "wemeet";
          terminal = false;
          categories = [ "AudioVideo" ];
          mimeType = [ "x-scheme-handler/wemeet" ];
          settings."Name[zh_CN]" = "腾讯会议";
        };
      };
  };
}
