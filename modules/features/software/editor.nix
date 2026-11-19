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
      let
        upstream = pkgs.so1ve.antigravity-hub;
        antigravity = pkgs.symlinkJoin {
          name = "${upstream.name}-fork";
          inherit (upstream) meta pname version;
          paths = [ upstream ];
          nativeBuildInputs = [
            pkgs.makeShellWrapper
            pkgs.python3
          ];
          postBuild = ''
            resources="$out/share/antigravity/resources"
            python3 ${./antigravity/enable-fork.py} \
              "$resources/bin/language_server" "$resources/web-ui.zip"
            wrapProgram "$resources/bin/language_server" \
              --add-flags "--web_bundle_path=$resources/web-ui.zip"

            # Electron resolves resources relative to the real executable.
            cp --reflink=auto --remove-destination \
              ${upstream}/share/antigravity/antigravity "$out/share/antigravity/antigravity"
            cp --remove-destination ${upstream}/bin/antigravity "$out/bin/antigravity"
            chmod u+w "$out/bin/antigravity"
            substituteInPlace "$out/bin/antigravity" --replace-fail \
              ${upstream}/share/antigravity/antigravity "$out/share/antigravity/antigravity"
          '';
        };
      in
      {
        home.packages = [
          (pkgs.so1ve.antigravity-ide.override {
            commandLineArgs = "--password-store=gnome-libsecret";
          })
          pkgs.so1ve.antigravity-cli
          antigravity
        ];
      };
  };
}
