{ config, lib, pkgs, ... }:

with lib;
let
  secretsDir = config.nix-bitcoin.secretsDir;

  inherit (config.services.backups) postgresqlDatabases;

  postgresqlBackupDir = config.services.postgresqlBackup.location;
  # TODO: Update this as soon as postgresql-back is enabled.
  postgresqlBackupPaths = map (db: "${postgresqlBackupDir}/${db}.sql.gz") postgresqlDatabases;
  postgresqlBackupServices = map (db: "postgresqlBackup-${db}.service") postgresqlDatabases;

  # Use borg 1.2.1 (the latest 1.2.* release)
  # TODO-EXTERNAL: Remove this when nixpkgs-unstable has been updated
  nixpkgs_borg_1_2_1 = pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "6616de389ed55fba6eeba60377fc04732d5a207c";
    sha256 = "1h8lvyrv4sb5fhimzniiw6zjn74hl30zm9g8nzcaq331bd20gpw6";
  };
  pkgs_borg_1_2_1 = import nixpkgs_borg_1_2_1 { config = {}; overlays = []; };
in
{
  # This configures the postgresql backups
  services.backups.enable = true;
  services.duplicity.enable = mkForce false;

  nixpkgs.overlays = [
    (_: _: { inherit (pkgs_borg_1_2_1) borgbackup; })
  ];

  services.borgbackup.jobs = {
    main = {
      paths = with config.services; [
        bitcoind.dataDir
        clightning.dataDir
        clightning-rest.dataDir
        liquidd.dataDir
        nbxplorer.dataDir
        btcpayserver.dataDir
        joinmarket.dataDir
        "/var/lib/tor"
        "/var/lib/nixos"
      ]
      ++ config.services.backups.extraFiles
      ++ postgresqlBackupPaths;

      exclude = with config.services; [
         "${bitcoind.dataDir}/blocks"
         "${bitcoind.dataDir}/chainstate"
         "${bitcoind.dataDir}/indexes"
         "${liquidd.dataDir}/*/blocks"
         "${liquidd.dataDir}/*/chainstate"
         "${liquidd.dataDir}/*/indexes"
      ];

      repo = "nixbitcoin@freak.seedhost.eu:borg-backup";
      doInit = false;
      encryption = {
        mode = "repokey";
        passCommand = "cat ${secretsDir}/backup-encryption-password";
      };
      environment = {
        BORG_RSH = "ssh -i ${secretsDir}/ssh-key-seedhost";
        # TODO-EXTERNAL: Use this definition when the borg job wrapper script
        # has been fixed in the borgbackup.nix NixOS module
        # BORG_REMOTE_PATH = "$HOME/.local/bin/borg";
        BORG_REMOTE_PATH = "/home34/nixbitcoin/.local/bin/borg";
      };
      compression = "zstd";
      startAt = "daily";
      prune.keep = {
        within = "1d"; # Keep all archives from the last day
        daily = 4;
        weekly = 2;
        monthly = 2;
      };
      # Compact (free repo storage space) every 7 days
      postPrune = ''
        if (( (($(date +%s) / 86400) % 7) == 0 )); then
          borg compact
        fi
      '';
    };
  };

  # TODO:
  # Reenable this as soon as postgresql runs faster
  # systemd.services.borgbackup-job-main = {
  #   wants = postgresqlBackupServices;
  #   after = postgresqlBackupServices;
  # };

  services.postgresqlBackup = {
    # Use native pg_dump compression
    compression = "none";
    pgdumpOptions =
      "-Fc " + # Use dump format that allows multithreaded importing
      "-Z9";   # Max compression level
  };

  nix-bitcoin.secrets = {
    backup-encryption-password.user = "root";
    ssh-key-seedhost = {
      user = "root";
      permissions = "600";
    };
  };
}
