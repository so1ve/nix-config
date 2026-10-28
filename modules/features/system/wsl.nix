{
  ray.features."system/wsl" = {
    requires.allOf = [
      "system/core"
      "system/nix"
      "security/sudo"
    ];

    nixos =
      _:
      {
        inputs,
        username,
        ...
      }:
      {
        imports = [ inputs.nixos-wsl.nixosModules.default ];

        wsl = {
          enable = true;
          defaultUser = username;
          useWindowsDriver = true;
        };
      };
  };
}
