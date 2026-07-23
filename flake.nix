{
  description = "Ray's NixOS Configuration";

  # Lets the initial root build use Noctalia's cache before these same
  # settings have been activated in /etc/nix/nix.conf.
  nixConfig = {
    extra-substituters = [
      "https://noctalia.cachix.org"
    ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The cachix branch tracks the newest Noctalia v5 revision available
    # from the project's binary cache.
    noctalia.url = "github:noctalia-dev/noctalia/cachix";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.vesper = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
        };

        modules = [
          ./hosts/vesper

          {
            nixpkgs.overlays = [
              (final: _prev: {
                unstable = import inputs.nixpkgs-unstable {
                  system = final.stdenv.hostPlatform.system;
                  config = final.config;
                };
              })
            ];
          }

          home-manager.nixosModules.home-manager

          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "home-manager.backup";
              users.ray = import ./home/ray;
            };
          }
        ];
      };

      checks.${system}.vesper = self.nixosConfigurations.vesper.config.system.build.toplevel;

      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          deadnix
          just
          nixd
          nixfmt
          statix
        ];
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };
}
