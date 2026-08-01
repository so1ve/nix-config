{
  lib,
  mkFocusOrLaunch,
}:

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
  focusOrLaunch = mkFocusOrLaunch pkgs;

  urlParts = builtins.match "https?://([^/]+)(/.*)?" url;
  urlHost = builtins.elemAt urlParts 0;
  urlPathMatch = builtins.elemAt urlParts 1;
  urlPath = if urlPathMatch == null then "/" else urlPathMatch;

  # Chromium derives the Wayland app ID from the app URL and profile name.
  chromiumAppId =
    assert lib.assertMsg (urlParts != null) "mkChromiumPwa requires an HTTP(S) URL";
    "chrome-${lib.replaceStrings [ "/" ] [ "_" ] "${urlHost}_${urlPath}"}-Default";

  launcher = pkgs.writeShellApplication {
    inherit name;
    text = ''
      exec ${lib.getExe focusOrLaunch} \
        ${lib.escapeShellArg chromiumAppId} \
        ${lib.getExe pkgs.chromium} \
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

  # Match Chromium's Wayland app ID so shells can associate the window with
  # this desktop entry instead of treating it as a generic Chromium window.
  xdg.desktopEntries.${chromiumAppId} = {
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
