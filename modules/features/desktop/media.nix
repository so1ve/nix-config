{
  ray.features."desktop/media" = {
    nixos =
      { inputs, pkgs, ... }:
      {
        # FIXME: Remove this pin once the Bluetooth reconnect/A2DP regression is fixed upstream:
        # https://github.com/bluez/bluez/issues/2524
        hardware.bluetooth.package =
          inputs.so1ve.packages.${pkgs.stdenv.hostPlatform.system}."bluez-5_86";

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
