{
  ray.registry = {
    users.ray = {
      description = "Ray";
      gitName = "so1ve";
      gitEmail = "58381667+so1ve@users.noreply.github.com";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
    };

    nixCacheSettings = {
      extra-substituters = [
        "https://nix-community.cachix.org"
        "https://noctalia.cachix.org"
        "https://so1ve.cachix.org"
      ];
      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
        "so1ve.cachix.org-1:51jcW4FkJhiLcqPsiUx3nglRP469les8F9zjFxio1nw="
      ];
    };
  };
}
