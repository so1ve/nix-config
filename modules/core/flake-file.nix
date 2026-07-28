{
  config,
  inputs,
  ...
}:

let
  binaryCaches = builtins.attrValues config.ray.registry.binaryCaches;
in
{
  imports = [ inputs.flake-file.flakeModules.default ];

  flake-file = {
    description = "Ray's NixOS Configuration";

    nixConfig = {
      extra-substituters = map (cache: cache.url) binaryCaches;
      extra-trusted-public-keys = map (cache: cache.publicKey) binaryCaches;
    };

    inputs = {
      nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

      flake-parts.url = "github:hercules-ci/flake-parts";
      flake-file.url = "github:denful/flake-file";
      import-tree.url = "github:denful/import-tree";

      nur = {
        url = "github:nix-community/NUR";
        inputs.nixpkgs.follows = "nixpkgs";
        inputs.flake-parts.follows = "flake-parts";
      };

      home-manager = {
        url = "github:nix-community/home-manager";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      agenix = {
        url = "github:ryantm/agenix";
        inputs.nixpkgs.follows = "nixpkgs";
        inputs.home-manager.follows = "home-manager";
        inputs.darwin.follows = "";
      };

      # Track the newest Noctalia v5 revision available from its binary cache.
      noctalia.url = "github:noctalia-dev/noctalia/cachix";

      noctalia-greeter = {
        url = "github:noctalia-dev/noctalia-greeter";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";

      waydroid-script = {
        url = "github:casualsnek/waydroid_script/d5289cfd8929e86e7f0dc89ecadcef8b66930eec";
        inputs.nixpkgs.follows = "nixpkgs";
      };
    };

    outputs = "inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules)";
  };
}
