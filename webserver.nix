let
  blog = import ./blog/default.nix {};
  acmeRoot = "/var/run/acme-challenges";


  httpDomainConfig = {name, docRoot, tlsReady ? false}: {
          enable = true;
          adminAddr = "nyarly@gmail.com";
          virtualHosts = [
            {
              hostName = name;
              serverAliases = [ "www.${name}" ];
              listen = [{ port = 80; }];

              documentRoot = docRoot;
              extraConfig = ''
                ${if tlsReady then "Redirect / https://${name}" else ""}
                Alias "/.well-known/acme-challenge" "${acmeRoot}/${name}/.well-known/acme-challenge"
                <Directory ${acmeRoot}/${name}>
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
                Alias "/.well-known/acme-challenge" "${acmeRoot}/${name}/.well-known/acme-challenge"
                <Directory ${acmeRoot}/${name}>
                  Require all granted
                </Directory>
              '';
            }
          ];
        };

in
  {
    network.description = "Web server";

    webserver =
      {  pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          neovim
          fish
        ];

        services.fail2ban.enable = true;

        services.httpd = httpDomainConfig {
          name = "judsonlester.info";
          docRoot = blog;
          tlsReady = true;
        };

        security.acme.certs = {
          "judsonlester.info" = {
            webroot = acmeRoot + "/judsonlester.info";
            email = "nyarly@gmail.com";
            postRun = "systemctl reload httpd.service";
          };
        };

        networking.firewall.allowedTCPPorts = [ 22 80 443 ];
      };
  }
