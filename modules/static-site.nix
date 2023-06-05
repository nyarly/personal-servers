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

  config = mkIf (builtins.length (builtins.attrNames config.staticWeb.sites) > 0) {
    services.httpd.virtualHosts = let
      vhosts = httpVhosts // httpsVhosts;
      httpVhosts = mapAttrs' httpVhost config.staticWeb.sites;
      httpsVhosts = mapAttrs' httpsVhost config.staticWeb.sites;

      httpVhost = name: hcfg: nameValuePair "${name}-http" {
          hostName = name;
          serverAliases = [ "www.${name}" ];
          listen = [{ port = 80; }];

          documentRoot = hcfg.docRoot;
          extraConfig = ''
          Redirect / https://${name}/
          Alias "/.well-known/acme-challenge" "${config.staticWeb.acmeRoot}/${name}/.well-known/acme-challenge"
          <Directory ${config.staticWeb.acmeRoot}/${name}>
          Require all granted
          </Directory>
          '';
        };
      httpsVhost = name: hcfg: nameValuePair "${name}-https" {
          hostName = name;
          serverAliases = [ "www.${name}" ];

          documentRoot = hcfg.docRoot;

          onlySSL = true;

          sslServerCert = "/var/lib/acme/${name}/full.pem";
          sslServerKey = "/var/lib/acme/${name}/key.pem";

          extraConfig = ''
          Alias "/.well-known/acme-challenge" "${config.staticWeb.acmeRoot}/${name}/.well-known/acme-challenge"
          <Directory ${config.staticWeb.acmeRoot}/${name}>
          Require all granted
          </Directory>
          '';
        };
    in vhosts;

    services.nsd.zones.staticweb.children = mapAttrs (name: value: {}) config.staticWeb.sites;

    security.acme.certs = let
      certs = mapAttrs siteToCertCfg config.staticWeb.sites;
      siteToCertCfg = domain: {...}: {
        webroot = config.staticWeb.acmeRoot + "/${domain}";
        email = "nyarly@gmail.com";
        postRun = "systemctl reload httpd.service";
        extraDomainNames = [ "www.${domain}" ];
      };
    in certs;

    systemd.services.httpd = {
      after = [ "acme-selfsigned-certificates.target" ];
      wants = [ "acme-selfsigned-certificates.target" "acme-certificates.target" ];
    };
  };
}
