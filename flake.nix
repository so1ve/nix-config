# DO-NOT-EDIT. This file was auto-generated using github:vic/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  description = "Ray's NixOS Configuration";

  outputs =
    inputs:
    (inputs.nixpkgs.lib.evalModules {
      specialArgs = {
        inherit inputs;
        inherit (inputs) self;
      };
      modules = [
        inputs.flake-file.flakeModules.flake
        ./flake-file.nix
      ];
    }).config.outputs
      inputs;

  nixConfig = {
    extra-substituters = [
      "https://attic.xuyh0120.win/lantian"
      "https://nix-community.cachix.org"
      "https://noctalia.cachix.org"
      "https://so1ve.cachix.org"
    ];
    extra-trusted-public-keys = [
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "so1ve.cachix.org-1:51jcW4FkJhiLcqPsiUx3nglRP469les8F9zjFxio1nw="
    ];
  };

  inputs = {
    agenix = {
      url = "github:ryantm/agenix";
      inputs = {
        darwin.follows = "";
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
      };
    };
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-file.url = "github:denful/flake-file";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    import-tree.url = "github:denful/import-tree";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    noctalia-greeter.url = "github:noctalia-dev/noctalia-greeter";
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    so1ve.url = "github:so1ve/nur-packages";
    waydroid-script = {
      url = "github:casualsnek/waydroid_script/d5289cfd8929e86e7f0dc89ecadcef8b66930eec";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
