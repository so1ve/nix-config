{
  ray.features."software/firefox" = {
    home = {
      programs.firefox = {
        enable = true;
        languagePacks = [ "zh-CN" ];
        policies.RequestedLocales = [ "zh-CN" ];
      };
    };
  };
}
