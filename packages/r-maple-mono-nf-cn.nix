{
  fetchurl,
  lib,
  stdenvNoCC,
  unzip,
}:

stdenvNoCC.mkDerivation {
  pname = "r-maple-mono-nf-cn";
  version = "7.9-1783947872";

  src = fetchurl {
    url = "https://github.com/so1ve/maple-font/releases/download/v1783947872/RMapleMono-NF-CN.zip";
    hash = "sha256-3tVLkchBXk82MDQFCWlkA3Y2+gxPIl8HBfvljW3DJvw=";
  };

  nativeBuildInputs = [ unzip ];
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/fonts/truetype"
    unzip -q -j "$src" '*.ttf' -d "$out/share/fonts/truetype"

    runHook postInstall
  '';

  meta = {
    description = "R Maple Mono";
    homepage = "https://github.com/so1ve/maple-font";
    license = lib.licenses.ofl;
    platforms = lib.platforms.all;
  };
}
