{ config, pkgs, lib, ... }:
let
cfg = {
  imports = [
    <nix-bitcoin/modules/presets/secure-node.nix>
    <nix-bitcoin/modules/presets/hardened.nix>

    ./hardware-configuration.nix
    ./website
    ./matrix.nix
    base
    services
  ];
};

base = {
  networking.hostName = "nixbitcoin-org";
  time.timeZone = "UTC";

  services.openssh.enable = true;
  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAO3kpItIalS3HHzqLRnXXFVRFtckuwE1FmytQ4HTh9u" # nixbitcoindev
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOVyeXpwHsOV8RMtQwzPGhOlJ8n5/+4hGa2jc7T47CJC" # nickler
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICW0rZHTE+/gRpbPVw0Q6Wr3csEgU7P+Q8Kw6V2xxDsG" # Erik Arvstedt
    ];
  };

  environment.systemPackages = with pkgs; [
    vim
  ];

  system.stateVersion = "20.09";

  nix-bitcoin.configVersion = "0.0.57";
};

services = {
  nix-bitcoin.onionServices.bitcoind.public = true;
  services.bitcoind = {
    i2p = true;
    tor.enforce = false;
    tor.proxy = false;
  };

  services.clightning = {
    enable = true;
    plugins.clboss.enable = true;
    extraConfig = ''
      alias=nixbitcoin.org
    '';
  };
  nix-bitcoin.onionServices.clightning.public = true;
  systemd.services.clightning.serviceConfig.TimeoutStartSec = "5m";

  services.electrs.enable = true;

  services.btcpayserver = {
    enable = true;
    lightningBackend = "clightning";
    lbtc = true;
  };
  nix-bitcoin.onionServices.btcpayserver.enable = true;

  nix-bitcoin.netns-isolation.enable = true;

  services.joinmarket = {
    enable = true;
    rpcWalletFile = null;
    yieldgenerator.enable = true;
  };
  services.joinmarket-ob-watcher.enable = true;

  nix-bitcoin-org.website = {
    enable = true;
    donate.btcpayserverAppId = "4D1Dxb5cGnXHRgNRBpoaraZKTX3i";
  };

  services.backups = {
    enable = true;
    destination = "sftp://nixbitcoin@freak.seedhost.eu";
  };
  programs.ssh.knownHosts."freak.seedhost.eu".publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBD2TmdE89ZD4XshcIcXZPLFC/nDxZdAr9yrH2/2OCNKEo/Ex60y8TQjp93isjdDj7Grf/GpW60OONfXTFe0r5iM=";

  # TODO-EXTERNAL
  # Remove this when https://github.com/NixOS/nixpkgs/issues/148009 is resolved
  systemd.services.nginx.serviceConfig.SystemCallFilter =
    lib.mkForce "~@cpu-emulation @debug @keyring @ipc @mount @obsolete @privileged @setuid";
};
in
  cfg
