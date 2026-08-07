{
  ray.features."system/wsl" = {
    requires = [
      "system/core"
      "system/nix"
      "security/sudo"
    ];

    nixos =
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

        # NixOS-WSL users do not have a password until one is explicitly set.
        security.sudo-rs.wheelNeedsPassword = false;

        # Required by VS Code Remote and other dynamically linked tools
        # downloaded outside of Nixpkgs.
        programs.nix-ld.enable = true;

        # A WSL virtual disk should not reserve the workstation's 50-100 GiB
        # Nix store free-space thresholds.
        nix.settings = {
          min-free = 1 * 1024 * 1024 * 1024;
          max-free = 5 * 1024 * 1024 * 1024;
        };
      };
  };
}
