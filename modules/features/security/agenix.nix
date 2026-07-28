{
  ray.features."security/agenix" = {
    nixos =
      {
        inputs,
        username,
        ...
      }:
      {
        imports = [ inputs.agenix.nixosModules.default ];

        age = {
          identityPaths = [ "/home/${username}/.config/agenix/identity" ];

          secrets.mihomo-config = {
            file = ../../../secrets/mihomo-config.age;
            owner = username;
          };
        };
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

        age = {
          identityPaths = [ "${config.xdg.configHome}/agenix/identity" ];

          secrets.github-ssh = {
            file = ../../../secrets/github-ssh.age;
            path = "${config.home.homeDirectory}/.ssh/id_ed25519_github";
          };
        };

        home.packages = [
          inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
        ];
      };
  };
}
