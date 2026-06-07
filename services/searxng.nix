# SearXNG — privacy-respecting meta-search engine.
# Used by Open WebUI for web search.
_: {
  services.searx = {
    enable = true;
    settings = {
      server = {
        port = 8890;
        bind_address = "::";
        secret_key = "@SEARX_SECRET_KEY@";
      };
      search = {
        autocomplete = "google";
        default_lang = "en";
      };
      outgoing.request_timeout = 10;
    };
    configureUwsgi = true;
    uwsgiConfig = {
      http = "[::]:8890";
      disable-logging = true;
    };
  };
}
