let
  cliLocale = "en_US.UTF-8";
in
{
  programs.bash = {
    enable = true;
    initExtra = ''
      export LANG=${cliLocale}
      export LANGUAGE=en_US
    '';
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -gx LANG ${cliLocale}
      set -gx LANGUAGE en_US
    '';
  };
}
