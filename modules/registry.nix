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

    binaryCaches.noctalia = {
      url = "https://noctalia.cachix.org";
      publicKey = "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=";
    };

    binaryCaches.nix-community = {
      url = "https://nix-community.cachix.org";
      publicKey = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
    };

    binaryCaches.so1ve = {
      url = "https://so1ve.cachix.org";
      publicKey = "so1ve.cachix.org-1:51jcW4FkJhiLcqPsiUx3nglRP469les8F9zjFxio1nw=";
    };
  };
}
