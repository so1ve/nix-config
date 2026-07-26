{
  alsa-lib,
  autoPatchelfHook,
  fetchurl,
  fontconfig,
  freetype,
  lib,
  libGL,
  libX11,
  libXext,
  libXi,
  libXrender,
  libXtst,
  libxkbcommon,
  stdenv,
  wayland,
  zlib,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "ab-download-manager";
  version = "1.10.1";

  src = fetchurl {
    url = "https://github.com/amir1376/ab-download-manager/releases/download/v${finalAttrs.version}/ABDownloadManager_${finalAttrs.version}_linux_x64.tar.gz";
    hash = "sha256-2q5TLfwHIx2uAvzjcaZrUObB70ypSnBbs7XyuZaCXuc=";
  };

  sourceRoot = "ABDownloadManager";

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [
    alsa-lib
    fontconfig
    freetype
    libGL
    libX11
    libXext
    libXi
    libXrender
    libXtst
    libxkbcommon
    stdenv.cc.cc.lib
    wayland
    zlib
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/opt/ab-download-manager"
    cp -r bin lib "$out/opt/ab-download-manager/"

    mkdir -p "$out/bin"
    for program in \
      ABDownloadManager \
      ABDownloadManagerCli \
      ABDownloadManagerNativeMessagingHost
    do
      ln -s "$out/opt/ab-download-manager/bin/$program" "$out/bin/$program"
    done

    install -Dm444 \
      "$out/opt/ab-download-manager/lib/ABDownloadManager.png" \
      "$out/share/pixmaps/com.abdownloadmanager.png"

    install -Dm444 /dev/stdin \
      "$out/share/applications/com.abdownloadmanager.desktop" <<EOF
    [Desktop Entry]
    Type=Application
    Name=AB Download Manager
    Comment=Manage and accelerate downloads
    Exec=ABDownloadManager %U
    Icon=com.abdownloadmanager
    Categories=Network;FileTransfer;
    Terminal=false
    StartupNotify=true
    EOF

    install -Dm444 /dev/stdin \
      "$out/lib/mozilla/native-messaging-hosts/com.abdownloadmanager.json" <<EOF
    {
      "name": "com.abdownloadmanager",
      "description": "AB Download Manager",
      "path": "$out/bin/ABDownloadManagerNativeMessagingHost",
      "type": "stdio",
      "allowed_extensions": [
        "firefox-integration@abdownloadmanager.com"
      ]
    }
    EOF

    runHook postInstall
  '';

  meta = {
    description = "Download manager with browser integration";
    homepage = "https://abdownloadmanager.com";
    license = lib.licenses.asl20;
    mainProgram = "ABDownloadManager";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
