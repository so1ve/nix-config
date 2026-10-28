{
  ray.features."desktop/media" = {
    nixos =
      _:
      { inputs, pkgs, ... }:
      {
        # FIXME: Remove this pin once the Bluetooth reconnect/A2DP regression is fixed upstream:
        # https://github.com/bluez/bluez/issues/2524
        hardware.bluetooth.package = (import inputs.so1ve { inherit pkgs; })."bluez-5_86";

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
