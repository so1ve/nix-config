{
  fetchzip,
  lib,
  proton-ge-bin,
}:

proton-ge-bin.overrideAttrs (
  finalAttrs: _:
  {
    pname = "dwproton-endfield-bin";
    version = "dwproton-10.0-26";
    steamDisplayName = "DWProton Endfield 10.0-26";

    src = fetchzip {
      url = "https://dawn.wine/dawn-winery/dwproton/releases/download/${finalAttrs.version}/${finalAttrs.version}-x86_64.tar.xz";
      hash = "sha256-TkwhJCHPS0PdDIEL5GrxJPR09uO9U2DR8l9KWFLIF2g=";
    };

    preFixup = ''
      substituteInPlace "$steamcompattool/compatibilitytool.vdf" \
        --replace-fail "${finalAttrs.version}" "${finalAttrs.steamDisplayName}"
    '';

    meta = {
      description = "DWProton version pinned for Arknights: Endfield compatibility";
      homepage = "https://dawn.wine/dawn-winery/dwproton";
      license = lib.licenses.bsd3;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  }
)
