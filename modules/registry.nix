{
  ray.registry = {
    nixCacheSettings = {
      extra-substituters = [
        # "https://cache.xinux.uz"
        "https://cache.lantian.pub/lantian"
        "https://cache.numtide.com"
        "https://codex-desktop-linux.cachix.org"
        "https://nix-community.cachix.org"
        "https://noctalia.cachix.org"
        "https://so1ve.cachix.org"
      ];
      extra-trusted-public-keys = [
        # "cache.xinux.uz:BXCrtqejFjWzWEB9YuGB7X2MV4ttBur1N8BkwQRdH+0="
        "lantian:WVGO7vsRMSEN+h7Lp7kv6SAmrkEXgUGbbXm7jMDjBuQ="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        "codex-desktop-linux.cachix.org-1:nX/xy6AdK9hQE24A8ALGjkCKj2ObFmcnemiL5Cid4nk="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
        "so1ve.cachix.org-1:51jcW4FkJhiLcqPsiUx3nglRP469les8F9zjFxio1nw="
      ];
    };
  };
}
