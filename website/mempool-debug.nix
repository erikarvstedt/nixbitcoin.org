{ config, lib, pkgs, ... }:

with lib;
let
  nbLib = config.nix-bitcoin.lib;
in
mkIf config.nixbitcoin-org.website.enable {
  services.nginx = {
    commonHttpConfig = ''
      proxy_cache_path
        /var/cache/nginx/mempool-api-debug
        keys_zone=mempool_api_debug:20m
        max_size=200m
        inactive=5d
        levels=1:2
        use_temp_path=off;
    '';

    virtualHosts."mempool-debug.nixbitcoin.org" = {
      forceSSL = true;
      enableACME = true;
      root = "/var/www/mempool";
      extraConfig = config.services.mempool.frontend.nginxConfig.staticContent +
                    builtins.readFile ./mempool-api-debug.conf;
    };

    upstreams = {
      "mempool-backend-debug" = {
        servers."10.10.0.2:8999" = {};
        extraConfig = ''
          keepalive 2;
        '';
      };
    };
  };
}
