let
  blog = import ./blog/default.nix {};
  acmeRoot = "/var/run/acme-challenges";
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

        services.httpd = {
          enable = true;
          adminAddr = "nyarly@gmail.com";
          virtualHosts = [
            {
              hostName = "judsonlester.info";
              serverAliases = [ "www.judsonlester.info" ];
              listen = [{ port = 80; }];
              extraConfig = ''
                Redirect / https://judsonlester.info
                Alias "/.well-known/acme-challenge" "${acmeRoot}/judsonlester.info/.well-known/acme-challenge"
                <Directory ${acmeRoot}/judsonlester.info>
                  Require all granted
                </Directory>
              '';

            }
            {
              hostName = "judsonlester.info";
              serverAliases = [ "www.judsonlester.info" ];
              listen = [{ port = 443; }];

              documentRoot = blog;
              enableSSL = true;
              sslServerCert = "/var/lib/acme/judsonlester.info/full.pem";
              sslServerKey = "/var/lib/acme/judsonlester.info/key.pem";

              extraConfig = ''
                Alias "/.well-known/acme-challenge" "${acmeRoot}/judsonlester.info/.well-known/acme-challenge"
                <Directory ${acmeRoot}/judsonlester.info>
                  Require all granted
                </Directory>
              '';
            }
          ];
        };

        security.acme.certs = {
          "judsonlester.info" = {
            webroot = acmeRoot + "/judsonlester.info";
            email = "nyarly@gmail.com";
          };
        };

        networking.firewall.allowedTCPPorts = [ 22 80 443 ];
      };
  }
