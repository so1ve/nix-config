{
  schema,
  dataPackage,
  suggestedDefault ? null,
  languageModel ? null,
}:

let
  fcitx5 = import ./mk-fcitx5.nix;

  rimePackage =
    pkgs:
    pkgs.fcitx5-rime.override {
      rimeDataPkgs = [ (dataPackage pkgs) ];
    };
in
{
  nixos =
    _:
    { pkgs, ... }:
    fcitx5.nixos pkgs "rime" [ (rimePackage pkgs) ];

  home =
    _:
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      rime = rimePackage pkgs;
      model =
        if languageModel == null then null else "${pkgs.so1ve.rime-lmdg}/share/rime-data/${languageModel}";
    in
    {
      imports = [ (fcitx5.home "rime") ];

      xdg.dataFile = {
        "fcitx5/rime/default.custom.yaml" = {
          text = lib.concatLines (
            [ "# shared-data: ${rime}" ]
            ++ lib.optional (model != null) "# language-model: ${model}"
            ++ [ "patch:" ]
            ++ lib.optional (suggestedDefault != null) "  __include: ${suggestedDefault}:/"
            ++ [
              "  schema_list:"
              "    - schema: ${schema}"
            ]
          );

          # Rime compares mtimes, while Nix store files are dated 1970. Rebuild
          # the generated cache explicitly whenever this managed file changes.
          onChange = ''
            rime_data_dir=${lib.escapeShellArg "${config.xdg.dataHome}/fcitx5/rime"}

            rm -rf "$rime_data_dir/build"
            ${pkgs.librime}/bin/rime_deployer \
              --build "$rime_data_dir" "${rime}/share/rime-data" "$rime_data_dir/build"

            (
              cd "$rime_data_dir"
              ${pkgs.librime}/bin/rime_deployer --set-active-schema ${schema}
            )
          '';
        };
      }
      // lib.optionalAttrs (model != null) {
        "fcitx5/rime/${languageModel}".source = model;
      };
    };
}
