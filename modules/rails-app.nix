{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.wagthepig;

  package = cfg.package;

  databaseConfig = builtins.toJSON { production = cfg.database; };

  wagthepigEnv = {
    RAILS_ENV = "production";
    RACK_ENV = "production";
    SECRET_KEY_BASE = cfg.secretKeyBase;
    FROM_EMAIL = cfg.fromEmail;
    RAILS_SERVE_STATIC_FILES = "1";
  } // cfg.extraEnvironment;

  wagthepig-rake = pkgs.stdenv.mkDerivation rec {
    name = "wagthepig-rake";
    buildInputs = [ package.env pkgs.makeWrapper ];
    phases = "installPhase fixupPhase";
    installPhase = ''
      mkdir -p $out/bin
      makeWrapper ${package.env}/bin/bundle $out/bin/wagthepig-bundle \
          ${concatStrings (mapAttrsToList (name: value: "--set ${name} '${value}' ") wagthepigEnv)} \
          --set PATH '${lib.makeBinPath (with pkgs; [ nodejs file imagemagick ])}:$PATH' \
          --set RAKEOPT '-f ${package}/share/wagthepig/Rakefile' \
          --run 'cd ${package}/share/wagthepig'
      makeWrapper $out/bin/wagthepig-bundle $out/bin/wagthepig-rake \
          --add-flags "exec rake"
     '';
  };

in

{
  options = {
    services.wagthepig = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable the wagthepig service.
        '';
      };

      package = mkOption {
      };

      host = mkOption {
        type = types.str;
        example = "wagthepig.example.com";
        description = ''
          Hostname under which this wagthepig instance can be reached.
        '';
      };

      protocol = mkOption {
        type = types.str;
        default = "https";
        example = "http";
        description = ''
          Either http or https, depending on how your Frab instance
          will be exposed to the public.
        '';
      };

      fromEmail = mkOption {
        type = types.str;
        default = "wagthepig@localhost";
        description = ''
          Email address used by wagthepig.
        '';
      };

      listenAddress = mkOption {
        type = types.str;
        default = "localhost";
        description = ''
          Address or hostname wagthepig should listen on.
        '';
      };

      listenPort = mkOption {
        type = types.int;
        default = 3000;
        description = ''
          Port wagthepig should listen on.
        '';
      };

      statePath = mkOption {
        type = types.str;
        default = "/var/lib/wagthepig";
        description = ''
          Directory where wagthepig keeps its state.
        '';
      };

      user = mkOption {
        type = types.str;
        default = "wagthepig";
        description = ''
          User to run wagthepig.
        '';
      };

      group = mkOption {
        type = types.str;
        default = "wagthepig";
        description = ''
          Group to run wagthepig.
        '';
      };

      secretKeyBase = mkOption {
        type = types.str;
        description = ''
          Your secret key is used for verifying the integrity of signed cookies.
          If you change this key, all old signed cookies will become invalid!

          Make sure the secret is at least 30 characters and all random,
          no regular words or you'll be exposed to dictionary attacks.
        '';
      };

      database = mkOption {
        type = types.attrs;
        default = {
          adapter = "sqlite3";
          database = "/var/lib/wagthepig/db.sqlite3";
          pool = 5;
          timeout = 5000;
        };
        example = {
          adapter = "postgresql";
          database = "wagthepig";
          host = "localhost";
          username = "wagthepiguser";
          password = "supersecret";
          encoding = "utf8";
          pool = 5;
        };
        description = ''
          Rails database configuration for Frab as Nix attribute set.
        '';
      };

      extraEnvironment = mkOption {
        type = types.attrs;
        default = {};
        example = {
          FRAB_CURRENCY_UNIT = "€";
          FRAB_CURRENCY_FORMAT = "%n%u";
          EXCEPTION_EMAIL = "wagthepig-owner@example.com";
          SMTP_ADDRESS = "localhost";
          SMTP_PORT = "587";
          SMTP_DOMAIN = "localdomain";
          SMTP_USER_NAME = "root";
          SMTP_PASSWORD = "toor";
          SMTP_AUTHENTICATION = "1";
          SMTP_NOTLS = "1";
        };
        description = ''
          Additional environment variables to set for wagthepig for further
          configuration. See the wagthepig documentation for more information.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ wagthepig-rake ];

    users.users = [
      { name = cfg.user;
        group = cfg.group;
        home = "${cfg.statePath}";
      }
    ];

    users.groups = [ { name = cfg.group; } ];

    systemd.services.wagthepig = {
      after = [ "network.target" "gitlab.service" ];
      wantedBy = [ "multi-user.target" ];
      environment = wagthepigEnv;

      preStart = ''
        mkdir -p ${cfg.statePath}/system/attachments
        chown ${cfg.user}:${cfg.group} -R ${cfg.statePath}

        mkdir /run/wagthepig -p
        ln -sf ${pkgs.writeText "wagthepig-database.yml" databaseConfig} /run/wagthepig/database.yml
        ln -sf ${cfg.statePath}/system /run/wagthepig/system

        if ! test -e "${cfg.statePath}/db-setup-done"; then
          ${wagthepig-rake}/bin/wagthepig-rake db:setup
          touch ${cfg.statePath}/db-setup-done
        else
          ${wagthepig-rake}/bin/wagthepig-rake db:migrate
        fi
      '';

      serviceConfig = {
        PermissionsStartOnly = true;
        PrivateTmp = true;
        PrivateDevices = true;
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        TimeoutSec = "300s";
        Restart = "on-failure";
        RestartSec = "10s";
        WorkingDirectory = "${package}/share/wagthepig";
        ExecStart = "${wagthepig-rake}/bin/wagthepig-bundle exec rails server " +
          "--binding=${cfg.listenAddress} --port=${toString cfg.listenPort}";
      };
    };

  };
}
