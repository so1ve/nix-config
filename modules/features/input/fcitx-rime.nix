{
  ray.features."input/fcitx-rime" = {
    nixos =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        rimeWithSchemas = pkgs.fcitx5-rime.override {
          rimeDataPkgs = config.ray.input.rime.dataPackages;
        };
      in
      {
        options.ray.input.rime.dataPackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          internal = true;
        };

        config = {
          assertions = [
            {
              assertion = config.ray.input.rime.dataPackages != [ ];
              message = "input/fcitx-rime requires at least one Rime schema feature";
            }
          ];

          i18n.inputMethod = {
            enable = true;
            type = "fcitx5";

            fcitx5 = {
              addons = [ rimeWithSchemas ];
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
      };

    home =
      {
        config,
        lib,
        ...
      }:
      let
        rime = config.ray.input.rime;
        schemaList = lib.concatMapStringsSep "\n" (schema: "    - schema: ${schema}") rime.schemas;
      in
      {
        options.ray.input.rime = {
          schemas = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            internal = true;
          };

          suggestedDefaults = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            internal = true;
          };
        };

        config = {
          assertions = [
            {
              assertion = rime.schemas != [ ] && rime.suggestedDefaults != [ ];
              message = "input/fcitx-rime requires at least one Rime schema feature";
            }
          ];

          xdg.dataFile."fcitx5/rime/default.custom.yaml".text = ''
            patch:
              __include: ${builtins.head rime.suggestedDefaults}:/
              schema_list:
            ${schemaList}
          '';
        };
      };
  };
}
