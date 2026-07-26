{
  ray.features."software/ab-download-manager" = {
    home =
      { pkgs, ... }:
      let
        abDownloadManager = pkgs.callPackage ../../../packages/ab-download-manager.nix { };
      in
      {
        home.packages = [ abDownloadManager ];

        programs.firefox = {
          nativeMessagingHosts = [ abDownloadManager ];

          policies.ExtensionSettings."firefox-integration@abdownloadmanager.com" = {
            installation_mode = "normal_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/ab-download-manager/latest.xpi";
            default_area = "navbar";
          };
        };
      };
  };
}
