{
  ray.hosts.nixos.vesper = {
    system = "x86_64-linux";
    type = "desktop";
    username = "ray";
    stateVersion = "26.05";
    homeStateVersion = "26.05";
    hardware = ./_hardware.nix;

    features = [
      "core/nix"
      "nixos/base"
      "nixos/desktop"
      "hardware/graphics"
      "hardware/uefi-systemd-boot"
      "home/base"
      "users/ray"
      "desktop/niri"
      "desktop/noctalia"
      "desktop/noctalia-greeter"
      "input/fcitx-rime"
      "ui/fonts"
      "software/dolphin"
      "software/mihomo"
      "software/netease-cloud-game"
      "software/codex"
      "software/firefox"
      "software/gaming"
      "software/wine"
      "software/git"
      "software/hmcl"
      "software/kitty"
      "software/alger-music-player"
      "software/neovim"
      "software/onlyoffice"
      "software/qq"
      "software/qbittorrent"
      "software/shell"
      "software/telegram-web"
      "software/tooling"
      "software/tmux"
      "software/waydroid"
      "software/wemeet"
      "software/wps"
      "security/agenix"
      "security/fingerprint"
    ];
  };
}
