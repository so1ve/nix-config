{
  ray.features."security/fingerprint" = {
    nixos = {
      services.fprintd.enable = true;

      security.pam.services = {
        # Keep the initial greeter login password-only.
        greetd.fprintAuth = false;

        # Noctalia scans fingerprints directly through fprintd while using
        # the login PAM service for passwords; avoid claiming the sensor twice.
        login.fprintAuth = false;
      };
    };
  };
}
