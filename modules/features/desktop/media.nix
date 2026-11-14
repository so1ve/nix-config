{
  ray.features."desktop/media" = {
    nixos =
      _:
      { pkgs, ... }:
      {
        # FIXME: Remove this pin once the Bluetooth reconnect/A2DP regression is fixed upstream:
        # https://github.com/bluez/bluez/issues/2524
        hardware.bluetooth.package = pkgs.so1ve.bluez-5_86;

        services = {
          pulseaudio.enable = false;

          pipewire = {
            enable = true;
            alsa.enable = true;
            alsa.support32Bit = true;
            pulse.enable = true;
          };
        };

        security.rtkit.enable = true;
      };
  };
}
