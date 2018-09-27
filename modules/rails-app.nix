{ config, lib, pkgs, ... }:

with lib;
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
        type = types.package;
        description = ''
          The package to use for wagthepig.
        '';
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
          Either http or https, depending on how your WagthePig instance
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
          Rails database configuration for WagthePig as Nix attribute set.
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

  config = mkIf config.services.wagthepig.enable
  (let
    cfg = config.services.wagthepig;

    package = cfg.package;

    databaseConfig = builtins.toJSON { production = cfg.database; };

    appEnv = {
      RAILS_ENV = "production";
      RACK_ENV = "production";
      # SECRET_KEY_BASE = cfg.secretKeyBase;
      FROM_EMAIL = cfg.fromEmail;
      RAILS_SERVE_STATIC_FILES = "1";
      BOOTSNAP_CACHE_DIR = cfg.statePath + "/tmp/cache";
    } // cfg.extraEnvironment;

    createDBuser = options:
      let
        db = options.services.wagthepig.database;
      in
        if db.adapter == "postgresql" then
          let
            pg = options.services.postgresql;
          in
            ''
              while ! ${pg.package}/bin/pg_isready -h ${db.host}; do
                sleep 0.1
              done
              ${pg.package}/bin/createuser -U ${pg.superUser} -h ${db.host} --echo --createdb --no-createrole --no-superuser ${db.username} || echo "already exists (probably)"
            ''
        else "echo Don't know how to set up user for database adapter: ${db.adapter}";

  in
    {
      users = {
        users = [
          { name = cfg.user;
            group = cfg.group;
            extraGroups = [ "keys" ];
            home = "${cfg.statePath}";
          }
        ];

        groups = [ { name = cfg.group; } ];
      };

      systemd.services.wagthepig = {
        after = [ "network.target" "wagthepig-key"];
        wants = [ "wagthepig-key" ];
        wantedBy = [ "multi-user.target" ];
        environment = appEnv;

        path = [ pkgs.nodejs ];

        preStart = ''
          mkdir -p $BOOTSNAP_CACHE_DIR
          mkdir -p ${cfg.statePath}/system/attachments
          mkdir -p ${cfg.statePath}/log
          chown ${cfg.user}:${cfg.group} -R ${cfg.statePath}

          mkdir ${package.runDir} -p
          ln -sf ${pkgs.writeText "wagthepig-database.yml" databaseConfig} ${package.runDir}/database.yml
          ln -sf ${cfg.statePath}/system ${package.runDir}/system
          ln -sf ${cfg.statePath}/log ${package.runDir}/log

          ${createDBuser config}

          export RAILS_MASTER_KEY=$(cat /run/keys/wagthepig)
          if ! test -e "${cfg.statePath}/db-setup-done"; then
            ${package.env}/bin/rake db:setup
            touch ${cfg.statePath}/db-setup-done
          else
            ${package.env}/bin/rake db:migrate
          fi
        '';

        script = ''
          id
          export RAILS_MASTER_KEY=$(cat /run/keys/wagthepig)
          ${package.env}/bin/rails server --binding=${cfg.listenAddress} --port=${toString cfg.listenPort}
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
        };
      };
    });
}
