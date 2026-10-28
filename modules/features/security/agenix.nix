{
  ray.features."security/agenix" = {
    nixos =
      _:
      {
        inputs,
        username,
        ...
      }:
      {
        imports = [ inputs.agenix.nixosModules.default ];

        age.identityPaths = [ "/home/${username}/.config/agenix/identity" ];
      };

    home =
      _:
      {
        config,
        inputs,
        pkgs,
        ...
      }:
      {
        imports = [ inputs.agenix.homeManagerModules.default ];

        age.identityPaths = [ "${config.xdg.configHome}/agenix/identity" ];

        home.packages = [
          inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
        ];

        home.shellAliases.ae = "agenix -i ~/.config/agenix/identity -e";
      };
  };
}
