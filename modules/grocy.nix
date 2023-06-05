{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.grocy;
in {
  options.services.grocy = {
    enable = mkEnableOption (lib.mdDoc "grocy");

    hostName = mkOption {
      type = types.str;
      description = lib.mdDoc ''
        FQDN for the grocy instance.
      '';
    };

    phpfpm.settings = mkOption {
      type = with types; attrsOf (oneOf [ int str bool ]);
      default = {
        "pm" = "dynamic";
        "php_admin_value[error_log]" = "stderr";
        "php_admin_flag[log_errors]" = true;
        "listen.owner" = "wwwrun";
        "catch_workers_output" = true;
        "pm.max_children" = "32";
        "pm.start_servers" = "2";
        "pm.min_spare_servers" = "2";
        "pm.max_spare_servers" = "4";
        "pm.max_requests" = "500";
      };

      description = lib.mdDoc ''
        Options for grocy's PHPFPM pool.
      '';
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/grocy";
      description = lib.mdDoc ''
        Home directory of the `grocy` user which contains
        the application's state.
      '';
    };

    settings = {
      currency = mkOption {
        type = types.str;
        default = "USD";
        example = "EUR";
        description = lib.mdDoc ''
          ISO 4217 code for the currency to display.
        '';
      };

      culture = mkOption {
        type = types.enum [ "de" "en" "da" "en_GB" "es" "fr" "hu" "it" "nl" "no" "pl" "pt_BR" "ru" "sk_SK" "sv_SE" "tr" ];
        default = "en";
        description = lib.mdDoc ''
          Display language of the frontend.
        '';
      };

      calendar = {
        showWeekNumber = mkOption {
          default = true;
          type = types.bool;
          description = lib.mdDoc ''
            Show the number of the weeks in the calendar views.
          '';
        };
        firstDayOfWeek = mkOption {
          default = null;
          type = types.nullOr (types.enum (range 0 6));
          description = lib.mdDoc ''
            Which day of the week (0=Sunday, 1=Monday etc.) should be the
            first day.
          '';
        };
      };
    };
  };

  config = mkIf cfg.enable {
    environment.etc."grocy/config.php".text = ''
      <?php
      Setting('CULTURE', '${cfg.settings.culture}');
      Setting('CURRENCY', '${cfg.settings.currency}');
      Setting('CALENDAR_FIRST_DAY_OF_WEEK', '${toString cfg.settings.calendar.firstDayOfWeek}');
      Setting('CALENDAR_SHOW_WEEK_OF_YEAR', ${boolToString cfg.settings.calendar.showWeekNumber});
    '';

    users.users.grocy = {
      isSystemUser = true;
      createHome = true;
      home = cfg.dataDir;
      group = "wwwrun";
    };

    systemd.tmpfiles.rules = map (
      dirName: "d '${cfg.dataDir}/${dirName}' - grocy wwwrun - -"
    ) [ "viewcache" "plugins" "settingoverrides" "storage" ];

    services.phpfpm.pools.grocy = {
      user = "grocy";
      group = "wwwrun";

      # PHP 8.0 is the only version which is supported/tested by upstream:
      # https://github.com/grocy/grocy/blob/v3.3.0/README.md#how-to-install
      phpPackage = pkgs.php80;

      inherit (cfg.phpfpm) settings;

      phpEnv = {
        GROCY_CONFIG_FILE = "/etc/grocy/config.php";
        GROCY_DB_FILE = "${cfg.dataDir}/grocy.db";
        GROCY_STORAGE_DIR = "${cfg.dataDir}/storage";
        GROCY_PLUGIN_DIR = "${cfg.dataDir}/plugins";
        GROCY_CACHE_DIR = "${cfg.dataDir}/viewcache";
      };
    };

    services.httpd = {
      #enable = true;
      extraModules = [ "proxy_fcgi" ];

      virtualHosts = {
          "groceries.madhelm.net" = let
            staticLocations = [];

            excludedLocations = map (loc: ''
            <Location /${loc}>
            ProxyPass !
            </Location>
            '') (staticLocations ++ [ ".well-known/acme-challenge" ]);

          in{
          hostName = "groceries.madhelm.net";

          documentRoot = "${pkgs.grocy}/public";

          forceSSL = true;
          enableACME = true;

          locations = {
            "/".extraConfig = ''
            RewriteEngine On
            RewriteCond %{REQUEST_FILENAME} !-d
            RewriteCond %{REQUEST_FILENAME} !-f
            RewriteRule ^ /index.php [QSA,L]
            '';
          };

          extraConfig = ''
          ProxyPassMatch ^/(.*\.php(/.*)?)$ "unix:${config.services.phpfpm.pools.grocy.socket}|fcgi://localhost/${pkgs.grocy}/public/"
          ${toString excludedLocations}
          DirectoryIndex /index.php index.php
          '';
        };
      };
    };
  };

  meta = {
    maintainers = with maintainers; [ ma27 ];
    #doc = ./grocy.xml;
  };
}
