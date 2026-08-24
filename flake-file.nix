{
  config,
  inputs,
  lib,
  ...
}:

let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};

  nixosConfigurations = lib.mapAttrs (
    _: host: config.ray.lib.mkNixosHost host
  ) config.ray.hosts.nixos;
in
{
  imports = [ (inputs.import-tree ./modules) ];

  flake-file = {
    description = "Ray's NixOS Configuration";
    outputs = "flake-module";

    nixConfig = config.ray.registry.nixCacheSettings;

    inputs = {
      nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

      nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel";

      nixos-wsl = {
        url = "github:nix-community/NixOS-WSL/main";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      flake-file.url = "github:denful/flake-file";
      import-tree.url = "github:denful/import-tree";

      latchshot.url = "github:so1ve/latchshot";

      chrome-url-router = {
        url = "github:so1ve/chrome-url-router";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      direnv-instant = {
        url = "github:Mic92/direnv-instant";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      nix-index-database = {
        url = "github:nix-community/nix-index-database";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      nix-alien.url = "github:thiagokokada/nix-alien";

      codex-desktop-linux.url = "github:ilysenko/codex-desktop-linux";

      codex-cli-nix = {
        url = "github:sadjow/codex-cli-nix";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      cloudflare-skills = {
        url = "github:cloudflare/skills";
        flake = false;
      };

      disko = {
        url = "github:nix-community/disko/latest";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      nur = {
        url = "github:nix-community/NUR";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      so1ve.url = "github:so1ve/nur-packages";

      home-manager = {
        url = "github:nix-community/home-manager";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      agenix = {
        url = "github:ryantm/agenix";
        inputs = {
          nixpkgs.follows = "nixpkgs";
          home-manager.follows = "home-manager";
          darwin.follows = "";
        };
      };

      noctalia-greeter.url = "github:noctalia-dev/noctalia-greeter";

      neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";

      waydroid-script = {
        url = "github:casualsnek/waydroid_script/d5289cfd8929e86e7f0dc89ecadcef8b66930eec";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      xwayclip.url = "github:so1ve/xwayclip";

    };
  };

  outputs = _: {
    inherit nixosConfigurations;

    checks.${system} =
      lib.mapAttrs (_: nixos: nixos.config.system.build.toplevel) nixosConfigurations
      // {
        check-flake-file = config.flake-file.check-flake-file pkgs;
      };

    formatter.${system} = pkgs.nixfmt-tree;
    packages.${system}.write-flake = config.flake-file.apps.write-flake pkgs;
  };
}
