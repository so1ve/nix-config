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
            addons = [
              rimeWithWanxiang
              pkgs.fcitx5-mellow-themes
            ];
            waylandFrontend = true;

            settings.inputMethod = {
              "Groups/0" = {
                Name = "Default";
                "Default Layout" = "us";
                DefaultIM = "rime";
              };

              "Groups/0/Items/0".Name = "rime";
              "Groups/0/Items/1".Name = "keyboard-us";
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
        rimeLmdg = pkgs.nur.repos.jetcookies.rime-lmdg;
      in
      {
        # Fcitx5-Qt renders the candidate window inside Qt applications and
        # only reads this user-level file, not /etc/xdg/fcitx5.
        xdg = {
          configFile."fcitx5/config".text = lib.generators.toINI { } {
            "Hotkey/TriggerKeys"."0" = "Super+space";
            # Do not let Fcitx consume Left Shift before Rime sees it.
            # Rime maps both Shift keys to the same ascii_mode toggle.
            "Hotkey/AltTriggerKeys"."0" = "";
          };

          configFile."fcitx5/conf/classicui.conf".text = ''
            Theme=mellow-wechat
            DarkTheme=mellow-wechat-dark
            UseDarkTheme=True
          '';

          dataFile."fcitx5/rime/default.custom.yaml" = {
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

              rm -rf "$rime_data_dir/build"
              ${pkgs.librime}/bin/rime_deployer \
                --build "$rime_data_dir" "${rimeWithWanxiang}/share/rime-data" "$rime_data_dir/build"

              (
                cd "$rime_data_dir"
                ${pkgs.librime}/bin/rime_deployer --set-active-schema wanxiang
              )
            '';
          };

          dataFile."fcitx5/rime/wanxiang-lts-zh-hans.gram".source =
            "${rimeLmdg}/share/rime-data/wanxiang-lts-zh-hans.gram";
        };
      };
  };
}
