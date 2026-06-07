_: {
  services.mosquitto = {
    enable = true;
    listeners = [
      {
        port = 1883;
        address = "0.0.0.0";
        omitPasswordAuth = true;
        settings.allow_anonymous = true;
        acl = ["topic readwrite #"];
      }
      {
        port = 1883;
        address = "::";
        omitPasswordAuth = true;
        settings.allow_anonymous = true;
        acl = ["topic readwrite #"];
      }
    ];
  };
}
