{ lib }:

{
  description,
  desktopFile,
  hash,
  homepage,
  iconPath,
  license,
  pkgs,
  pname,
  url,
  version,
}:

let
  src = pkgs.fetchurl {
    inherit hash url;
  };

  appimageContents = pkgs.appimageTools.extractType2 {
    inherit pname src version;
  };

  iconInstallPath = lib.removePrefix "usr/" iconPath;
  iconFileName = builtins.baseNameOf iconPath;
in
pkgs.appimageTools.wrapType2 {
  inherit pname src version;

  extraInstallCommands = ''
    install -m 444 -D \
      "${appimageContents}/${desktopFile}" \
      "$out/share/applications/${desktopFile}"
    substituteInPlace "$out/share/applications/${desktopFile}" \
      --replace-fail "Exec=AppRun" "Exec=${pname}"
    install -m 444 -D \
      "${appimageContents}/${iconPath}" \
      "$out/${iconInstallPath}"
    install -m 444 -D \
      "${appimageContents}/${iconPath}" \
      "$out/share/pixmaps/${iconFileName}"
  '';

  meta = {
    inherit description homepage license;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
