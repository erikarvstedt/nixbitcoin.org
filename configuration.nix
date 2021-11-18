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
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAO3kpItIalS3HHzqLRnXXFVRFtckuwE1FmytQ4HTh9u" ];
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
    enforceTor = lib.mkForce false;
  };

  nix-bitcoin.pkgs = let
    nbpkgs = (import <nix-bitcoin/pkgs> { inherit pkgs; }).modulesPkgs;
    clightning = nbpkgs.clightning.overrideAttrs (old: rec {
      configurePhase = "./configure --prefix=$out --enable-developer --disable-valgrind";
    });
  in
    nbpkgs // { inherit clightning; };

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
    donate.btcpayserverAppIdLnurl = "TODO";
  };

  services.backups.enable = true;
};
in
  cfg
