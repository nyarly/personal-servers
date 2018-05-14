{ config, lib, pkgs, ...}:
with lib;
{
  options = {
    staticWeb = {
        acmeRoot = mkOption {
        type = with types; path;
        description = "The path that ACME clients will use for challenges.";
      };

      sites = mkOption {
        default = {};
        type = with types; attrsOf (submodule {
          options = {
            docRoot = mkOption { type = path; };
          };
        });
        description = ''
          Attribute set of static sites.
        '';

        example = literalExample ''
          judsonlester.info = {
            docRoot = blog;
          };
        '';
      };
    };
  };

  config = {
    services.httpd.virtualHosts = let
      vhosts =  concatLists (mapAttrsToList nameToVHost config.staticWeb.sites);
      nameToVHost = name: hcfg:
      let
        inherit (hcfg) docRoot;
      in
      [
        {
          hostName = name;
          serverAliases = [ "www.${name}" ];
          listen = [{ port = 80; }];

          documentRoot = docRoot;
          extraConfig = ''
                Redirect / https://${name}
                Alias "/.well-known/acme-challenge" "${config.staticWeb.acmeRoot}/${name}/.well-known/acme-challenge"
                <Directory ${config.staticWeb.acmeRoot}/${name}>
                  Require all granted
                </Directory>
          '';
        }

        {
          hostName = name;
          serverAliases = [ "www.${name}" ];
          listen = [{ port = 443; }];

          documentRoot = docRoot;
          enableSSL = true;
          sslServerCert = "/var/lib/acme/${name}/full.pem";
          sslServerKey = "/var/lib/acme/${name}/key.pem";

          extraConfig = ''
                Alias "/.well-known/acme-challenge" "${config.staticWeb.acmeRoot}/${name}/.well-known/acme-challenge"
                <Directory ${config.staticWeb.acmeRoot}/${name}>
                  Require all granted
                </Directory>
          '';
        }
      ];
    in vhosts;

    security.acme.certs = let
      certs = listToAttrs (concatLists (mapAttrsToList siteToCertCfg config.staticWeb.sites));
      siteToCertCfg = domain: {...}:
      let
        cfg = {
            webroot = config.staticWeb.acmeRoot + "/${domain}";
            email = "nyarly@gmail.com";
            postRun = "systemctl reload httpd.service";
          };
        in [ {
          name = domain;
          value = cfg;
          extraDomains = { "www.${domain}" = null; };
        } ];
    in certs;

    systemd.services.httpd = {
      after = [ "acme-selfsigned-certificates.target" ];
      wants = [ "acme-selfsigned-certificates.target" "acme-certificates.target" ];
    };
  };
}
