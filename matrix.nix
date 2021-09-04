# This config enables
# - Matrix Synapse homeserver available at synapse.nixbitcoin.org
# - Matrix Element web client available at element.nixbitcoin.org
#
# Inspired by https://github.com/alarsyo/nixos-config/blob/main/services/matrix.nix

{ config, lib, pkgs, ... }:

with lib;

let
  nbLib = config.nix-bitcoin.lib;
  secretsDir = config.nix-bitcoin.secretsDir;
  netns = config.nix-bitcoin.netns-isolation.netns;

  synapseAddress = netns.matrix-synapse.address;
  synapsePort = 8008;
in {
  imports = [ ./mail.nix ];

  # Limit systemd log retention for privacy reasons
  services.journald.extraConfig = ''
    MaxRetentionSec=24h
    MaxFileSec=7day
  '';

  nix-bitcoin.netns-isolation.services = {
    matrix-synapse = {
      id = 28;
      connections = [ "nginx" ];
    };
  };

  services.tor.relay.onionServices.matrix-synapse = nbLib.mkOnionService {
    port = 80;
    target.addr = synapseAddress;
    target.port = synapsePort;
  };

  #TODO: Add database and dataDir to backup files
  services.postgresql = {
    enable = true;
    initialScript = builtins.toFile "synapse-init.sql" ''
      CREATE ROLE "matrix-synapse" WITH LOGIN PASSWORD 'synapse';
      CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
        TEMPLATE template0
        LC_COLLATE = "C"
        LC_CTYPE = "C";
    '';
  };

  services.matrix-synapse = {
    enable = true;
    enable_registration = true;
    extraConfigFiles =  [ "${secretsDir}/matrix-email" ];
    database_args = {
      database = "matrix-synapse";
      user = "matrix-synapse";
      host = "/run/postgresql";
    };
    server_name = "nixbitcoin.org";
    public_baseurl = "https://synapse.nixbitcoin.org";
    listeners = [
      {
        bind_address = synapseAddress;
        port = synapsePort;
        type = "http";
        tls = false;
        x_forwarded = true;
        resources = [
          {
            names = [ "client" "federation" ];
            compress = false;
          }
        ];
      }
    ];
    extraConfig = ''
      push:
        include_content: false

      registrations_require_3pid:
        - email

      enable_metrics: false
      report_stats: false

      auto_join_rooms:
        - "#general:nixbitcoin.org"

      retention:
        enabled: true
        purge_jobs:
        - longest_max_lifetime: 1w
          interval: 12h

      allow_profile_lookup_over_federation: false
      allow_device_name_lookup_over_federation: false
      include_profile_data_on_invite: false
      limit_profile_requests_to_users_who_share_rooms: true
      require_auth_for_profile_requests: true
    '';
  };

  systemd.services.matrix-synapse.serviceConfig =
    nbLib.defaultHardening //
    nbLib.allowAllIPAddresses // {
      ReadWritePaths = config.services.matrix-synapse.dataDir;
      MemoryDenyWriteExecute = false;
    };

  services.nginx = {
    enable = true;
    # Only recommendedProxySettings and recommendedGzipSettings are strictly required,
    # but the rest make sense as well
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;

    virtualHosts = {
      # .well-known locations for matrix
      "nixbitcoin.org" = {
        enableACME = true;
        forceSSL = true;

        locations."= /.well-known/matrix/server".extraConfig = ''
            add_header Content-Type application/json;
            return 200 '${builtins.toJSON {
              # use 443 instead of the default 8448 port to unite
              # the client-server and server-server port for simplicity
              "m.server" = "synapse.nixbitcoin.org:443";
            }}';
          '';
        locations."= /.well-known/matrix/client".extraConfig =
          # ACAO required to allow element-web on any URL to request this json file
          ''
            add_header Content-Type application/json;
            add_header Access-Control-Allow-Origin *;
            return 200 '${builtins.toJSON {
              "m.homeserver" =  { "base_url" = "https://synapse.nixbitcoin.org"; };
              "m.identity_server" =  { "base_url" = "https://vector.im"; };
            }}';
          '';
      };

      # Reverse proxy for Matrix client-server and server-server communication
      "synapse.nixbitcoin.org" = {
        enableACME = true;
        forceSSL = true;

        # Don't show nginx welcome page
        locations."/".extraConfig = ''
          return 404;
        '';

        # forward all Matrix API calls to the synapse Matrix homeserver
        locations."/_matrix" = {
          proxyPass = "http://${synapseAddress}:${toString synapsePort}";
        };
      };

      "element.nixbitcoin.org" = {
        enableACME = true;
        forceSSL = true;

	      root = pkgs.element-web.override {
	        conf = {
	          default_server_config."m.homeserver" = {
	            "base_url" = "https://synapse.nixbitcoin.org";
	            "server_name" = "nixbitcoin.org";
	          };
	        };
	      };
      };
    };
  };

  nix-bitcoin.secrets.matrix-email.user = "matrix-synapse";
}
