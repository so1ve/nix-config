{
  ray.features."input/fcitx-rime" = {
    nixos =
      { pkgs, ... }:
      let
        rimeWithWanxiang = pkgs.fcitx5-rime.override {
          rimeDataPkgs = [ pkgs.rime-wanxiang ];
        };
      in
      {
        i18n.inputMethod = {
          enable = true;
          type = "fcitx5";

          fcitx5 = {
            addons = [ rimeWithWanxiang ];
            waylandFrontend = true;

            settings.globalOptions = {
              "Hotkey/TriggerKeys"."0" = "Super+space";
            };

            settings.inputMethod = {
              "Groups/0" = {
                Name = "Default";
                "Default Layout" = "us";
                DefaultIM = "rime";
              };

              "Groups/0/Items/0".Name = "keyboard-us";
              "Groups/0/Items/1".Name = "rime";
              GroupOrder."0" = "Default";
            };
          };
        };

        # Qt does not support the text-input-v3 protocol used by Niri.
        environment.variables.QT_IM_MODULE = "fcitx";
      };

    home =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        rimeWithWanxiang = pkgs.fcitx5-rime.override {
          rimeDataPkgs = [ pkgs.rime-wanxiang ];
        };
      in
      {
        xdg.dataFile."fcitx5/rime/default.custom.yaml" = {
          text = ''
            # shared-data: ${rimeWithWanxiang}
            patch:
              __include: wanxiang_suggested_default:/
              schema_list:
                - schema: wanxiang
          '';

          # Rime compares mtimes, while Nix store files are dated 1970. Rebuild
          # the generated cache explicitly whenever this managed file changes.
          onChange = ''
            rime_data_dir=${lib.escapeShellArg "${config.xdg.dataHome}/fcitx5/rime"}

            rm -f "$rime_data_dir/build/default.yaml"
            ${pkgs.librime}/bin/rime_deployer \
              --build "$rime_data_dir" "${rimeWithWanxiang}/share/rime-data" "$rime_data_dir/build"

            (
              cd "$rime_data_dir"
              ${pkgs.librime}/bin/rime_deployer --set-active-schema wanxiang
            )
          '';
        };

        xdg.dataFile."fcitx5/rime/wanxiang-lts-zh-hans.gram".source = pkgs.fetchurl {
          url = "https://github.com/amzxyz/RIME-LMDG/releases/download/LTS/wanxiang-lts-zh-hans.gram";
          hash = "sha256-KAzOrsRfEOlqT9fUCSanjS2qQJyxrULK5NBe9/Ai7vM=";
        };
      };
  };
}
