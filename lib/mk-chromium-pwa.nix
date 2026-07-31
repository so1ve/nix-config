{ lib }:

{
  config,
  pkgs,
  name,
  desktopName,
  description,
  url,
  icon,
  categories ? [ "Network" ],
}:

let
  launcher = pkgs.writeShellApplication {
    inherit name;
    text = ''
      exec ${lib.getExe pkgs.chromium} \
        --app=${lib.escapeShellArg url} \
        --class=${lib.escapeShellArg name} \
        --no-first-run \
        --user-data-dir=${lib.escapeShellArg "${config.xdg.dataHome}/chromium-pwa/${name}"} \
        "$@"
    '';
  };
in
{
  home.packages = [ launcher ];

  xdg.desktopEntries.${name} = {
    name = desktopName;
    comment = description;
    genericName = "Web App";
    exec = lib.getExe launcher;
    inherit icon;
    terminal = false;
    inherit categories;
    settings.StartupWMClass = name;
  };
}
