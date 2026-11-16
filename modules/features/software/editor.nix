{
  ray.features = {
    "software/neovim" = {
      home =
        _:
        {
          inputs,
          mkDotfilesSource,
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
              age
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

          xdg.configFile."nvim".source = mkDotfilesSource "nvim";
        };
    };

    "software/zed" = {
      home = _: { programs.zed-editor.enable = true; };
    };

    "software/antigravity".home =
      _:
      { pkgs, ... }:
      {
        home.packages = [
          (pkgs.so1ve.antigravity-ide.override {
            commandLineArgs = "--password-store=gnome-libsecret";
          })
          pkgs.so1ve.antigravity-cli
          pkgs.so1ve.antigravity-hub
        ];
      };
  };
}
