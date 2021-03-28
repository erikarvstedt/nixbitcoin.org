{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.nix-bitcoin-org.website;

  nginxAddress = if config.nix-bitcoin.netns-isolation.enable then
    config.nix-bitcoin.netns-isolation.netns.nginx.address
  else
    "localhost";
in {
  options.nix-bitcoin-org.website = {
    enable = mkEnableOption "nix-bitcoin.org website";
    host = mkOption {
      type = types.str;
      default = if config.nix-bitcoin.netns-isolation.enable then
        config.nix-bitcoin.netns-isolation.netns.nginx.address
      else
        "localhost";
      description = "HTTP server listen address.";
    };
  };

  config = mkIf cfg.enable {

    systemd.tmpfiles.rules = [
      # Create symlink to static website content
      "L+ /var/www - - - - ${./static}"
    ];

    networking.nat = {
      enable = true;
      externalInterface = "enp2s0";
      forwardPorts = [
        {
          destination = "169.254.1.21:80";
          proto = "tcp";
          sourcePort = 80;
        }
        {
          destination = "169.254.1.21:443";
          proto = "tcp";
          sourcePort = 443;
        }
      ];
    };
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
    nix-bitcoin.netns-isolation.services.btcpayserver.connections = [ "nginx" ];
    nix-bitcoin.netns-isolation.services.joinmarket-ob-watcher.connections = [ "nginx" ];

    # Allow connections from outside netns
    systemd.services.netns-nginx.postStart = ''
      ${pkgs.iproute}/bin/ip netns exec nb-nginx ${config.networking.firewall.package}/bin/iptables \
        -w -A INPUT -p TCP -m multiport --dports 80,443 -j ACCEPT
    '';

    security.acme = {
      email = "nixbitcoin@i2pmail.org";
      acceptTerms = true;
    };
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedTlsSettings = true;
      commonHttpConfig = ''
        # Disable the access log for user privacy
        access_log off;
      '';
      virtualHosts."nixbitcoin.org" = {
        forceSSL = true;
        root = "/var/www";
        enableACME = true;
        locations."/btcpayserver/" = {
          proxyPass = "http://169.254.1.24:23000";
        };
        extraConfig = ''
          location /obwatcher/ {
            proxy_pass http://${toString config.services.joinmarket-ob-watcher.address}:${toString config.services.joinmarket-ob-watcher.port};
            rewrite /obwatcher/(.*) /$1 break;
          }
          add_header Onion-Location http://qvzlxbjvyrhvsuyzz5t63xx7x336dowdvt7wfj53sisuun4i4rdtbzid.onion$request_uri;
        '';
      };
      virtualHosts."_" = {
        root = "/var/www";
        locations."/btcpayserver/" = {
          proxyPass = "http://169.254.1.24:23000";
        };
        extraConfig = ''
          location /obwatcher/ {
            proxy_pass http://${toString config.services.joinmarket-ob-watcher.address}:${toString config.services.joinmarket-ob-watcher.port};
            rewrite /obwatcher/(.*) /$1 break;
          }
        '';
      };
    };
    systemd.services."acme-nixbitcoin.org".serviceConfig.NetworkNamespacePath = "/var/run/netns/nb-nginx";

    services.btcpayserver.rootpath = "btcpayserver";

    services.tor.hiddenServices.nginx = {
      map = [{
        port = 80; toHost = cfg.host;
      } {
        port = 443; toHost = cfg.host;
      }];
      version = 3;
    };
  };
}
