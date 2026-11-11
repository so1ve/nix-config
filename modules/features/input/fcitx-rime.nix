let
  fcitx5 = import ../../../lib/mk-fcitx5.nix;

  mkRimeWithFrost =
    pkgs: frost:
    pkgs.fcitx5-rime.override {
      rimeDataPkgs = [ frost ];
    };
in
{
  ray.features."input/fcitx-rime" = {
    nixos =
      _:
      { inputs, pkgs, ... }:
      let
        personalPackages = import inputs.so1ve { inherit pkgs; };
        rimeWithFrost = mkRimeWithFrost pkgs personalPackages.rime-frost;
      in
      fcitx5.nixos pkgs "rime" [ rimeWithFrost ];

    home =
      _:
      {
        config,
        inputs,
        lib,
        pkgs,
        ...
      }:
      let
        personalPackages = import inputs.so1ve { inherit pkgs; };
        rimeWithFrost = mkRimeWithFrost pkgs personalPackages.rime-frost;
      in
      {
        imports = [ fcitx5.home ];

        xdg.dataFile."fcitx5/rime/default.custom.yaml" = {
          text = ''
            # shared-data: ${rimeWithFrost}
            patch:
              schema_list:
                - schema: rime_frost
          '';

          # Rime compares mtimes, while Nix store files are dated 1970. Rebuild
          # the generated cache explicitly whenever this managed file changes.
          onChange = ''
            rime_data_dir=${lib.escapeShellArg "${config.xdg.dataHome}/fcitx5/rime"}

            rm -rf "$rime_data_dir/build"
            ${pkgs.librime}/bin/rime_deployer \
              --build "$rime_data_dir" "${rimeWithFrost}/share/rime-data" "$rime_data_dir/build"

            (
              cd "$rime_data_dir"
              ${pkgs.librime}/bin/rime_deployer --set-active-schema rime_frost
            )
          '';
        };
      };
  };
}
