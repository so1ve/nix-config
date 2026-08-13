{
  ray.features."security/agenix" = {
    requires = [ "software/shell" ];

    nixos =
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

        programs.fish.shellAbbrs.ae = "agenix -i ~/.config/agenix/identity -e";
      };
  };
}
