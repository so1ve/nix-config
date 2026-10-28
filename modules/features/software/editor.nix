{
  ray.features = {
    "software/neovim" = {
      home =
        _:
        {
          config,
          inputs,
          mkDotfilesSymlink,
          pkgs,
          system,
          ...
        }:
        {
          programs.neovim = {
            enable = true;
            package = inputs.neovim-nightly-overlay.packages.${system}.default;
            sideloadInitLua = true;
            extraPackages = with pkgs; [
              bash-language-server
              copilot-language-server
              curl
              fish-lsp
              gnutar
              shellcheck
              shfmt
              stdenv.cc
              tree-sitter
            ];
          };

          xdg.configFile."nvim".source = mkDotfilesSymlink {
            inherit config;
            name = "nvim";
          };
        };
    };

    "software/zed" = {
      home = _: { programs.zed-editor.enable = true; };
    };
  };
}
