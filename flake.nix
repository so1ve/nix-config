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

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:denful/import-tree";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
      inputs.darwin.follows = "";
    };

    # The cachix branch tracks the newest Noctalia v5 revision available
    # from the project's binary cache.
    noctalia.url = "github:noctalia-dev/noctalia/cachix";

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    waydroid-script = {
      url = "github:casualsnek/waydroid_script/d5289cfd8929e86e7f0dc89ecadcef8b66930eec";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
