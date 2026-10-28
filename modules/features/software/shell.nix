{ lib, ... }:

{
  ray.features."software/shell" = {
    options.shells = lib.mkOption {
      type = lib.types.listOf (
        lib.types.enum [
          "bash"
          "fish"
        ]
      );
      default = [ "bash" ];
      description = "Interactive shells to configure";
    };

    nixos = settings: {
      programs.fish.enable = lib.elem "fish" settings.shells;
    };

    home =
      settings:
      {
        config,
        mkDotfilesSymlink,
        ...
      }:
      let
        cliLocale = "en_US.UTF-8";
        bashEnabled = lib.elem "bash" settings.shells;
        fishEnabled = lib.elem "fish" settings.shells;
      in
      {
        home = {
          shell = {
            enableBashIntegration = lib.mkDefault config.programs.bash.enable;
            enableFishIntegration = lib.mkDefault config.programs.fish.enable;
          };
          shellAliases = {
            nd = ''nix develop -c "$SHELL"'';
            sr = "steam-run";
          };
        };

        programs = {
          bash = {
            enable = bashEnabled;
            initExtra = lib.mkIf bashEnabled ''
              export LANG=${cliLocale}
              export LANGUAGE=en_US
            '';
          };

          fish = {
            enable = fishEnabled;
            interactiveShellInit = lib.mkIf fishEnabled ''
              set -gx LANG ${cliLocale}
              set -gx LANGUAGE en_US
              set -g fish_greeting
            '';
          };

          starship.enable = true;
          zoxide.enable = true;
        };

        xdg.configFile."starship.toml".source = mkDotfilesSymlink {
          inherit config;
          name = "starship.toml";
        };
      };
  };
}
