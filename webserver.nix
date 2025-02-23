let
  acmeRoot = "/var/lib/acme";

  ports = {
    wagthepig = 3000;
  };

  buddyNSServers = [
    "108.61.224.67 NOKEY"
    "116.203.6.3 NOKEY"
    "107.191.99.111 NOKEY"
    "185.22.172.112 NOKEY"
    "103.6.87.125 NOKEY"
    "192.184.93.99 NOKEY"
    "119.252.20.56 NOKEY"
    "31.220.30.73 NOKEY"
    "185.34.136.178 NOKEY"
    "185.136.176.247 NOKEY"
    "45.77.29.133 NOKEY"
    "116.203.0.64 NOKEY"
    "167.88.161.228 NOKEY"
    "199.195.249.208 NOKEY"
    "104.244.78.122 NOKEY"
    "2001:19f0:6400:8642::3 NOKEY"
    "2a01:4f8:1c0c:8115::3 NOKEY"
    "2604:180:2:4cf::3 NOKEY"
    "2a00:1838:20:2::cd5e:68e9 NOKEY"
    "2403:2500:4000::f3e NOKEY"
    "2604:180:1:92a::3 NOKEY"
    "2401:1400:1:1201::1:7853:1a5 NOKEY"
    "2a04:bdc7:100:1b::3 NOKEY"
    "2a00:dcc7:d3ff:88b2::1 NOKEY"
    "2a06:fdc0:fade:2f7::1 NOKEY"
    "2001:19f0:7001:381::3 NOKEY"
    "2a01:4f8:1c0c:8122::3 NOKEY"
    "2605:6400:20:d5e::3 NOKEY"
    "2605:6400:10:65::3 NOKEY"
    "2605:6400:30:fd6e::3 NOKEY"
  ];
in
  {
    network.description = "Web server";

    webserver = { lib, config, pkgs, ... }:
    let
      keys = import secrets/webserver-keys.nix;
      pubIP = config.networking.publicIPv4;
      blog = pkgs.callPackage packages/blog/default.nix {};
      wagthepig = pkgs.callPackage packages/wagthepig/default.nix {
        masterKey = keys.wagthepig.text;
      };
      wrapQuotes = str: ''"${str}"'';
      #dnsLines = path: lib.strings.concatStringsSep "\n" (map wrapQuotes (lib.strings.splitString "\n" (builtins.readFile path)));
      baseDNSZone = ''
        $TTL 18000  ; 5 hours
        @ IN SOA  ns1.lrdesign.com. nyarly.gmail.com. (
            2019101501 ; serial
            10800      ; refresh (3 hours)
            3600       ; retry (1 hour)
            18000      ; expire (5 hours)
            18000      ; minimum (5 hours)
        )
                       NS uz5dkwpjfvfwb9rh1qj93mtup0gw65s6j7vqqumch0r9gzlu8qxx39.pro.ns.buddyns.com.
                       NS uz5qfm8n244kn4qz8mh437w9kzvpudduwyldp5361v9n0vh8sx5ucu.pro.ns.buddyns.com.
                       NS uz588h0rhwuu3cc03gm9uckw0w42cqr459wn1nxrbzhym2wd81zydb.pro.ns.buddyns.com.
                       NS uz53c7fwlc89h7jrbxcsnxfwjw8k6jtg56l4yvhm6p2xf496c0xl40.pro.ns.buddyns.com.
                       NS uz56xw8h7fw656bpfv84pctjbl9rbzbqrw4rpzdhtvzyltpjdmx0zq.pro.ns.buddyns.com.

                       A        ${pubIP}
                       RP     @ nyarly.gmail.com.
        blog           CNAME  @
        gems           CNAME  @
        repos          CNAME  @
        www            CNAME  @
        tasks          CNAME  @
        groceries          CNAME  @
      '';
      /*
        @          IN  TXT    "v=spf1 +a +mx ip4:${pubIP} -all"
        @          IN  TXT    "google-site-verification=PdMCpmcPxMhcuIeabkjGH2AcasilKqCatBs98MxkImk"
        _domainkey IN  TXT    "o=-\;"
        dkim._domainkey IN  TXT ("v=DKIM1\; t=y\; k=rsa\; p="
          ${dnsLines secrets/dkim.cert.bare}
          )
        @          IN  TXT    "v=DMARC1;p=reject;sp=reject;ruf=mailto:nyarly@gmail.com"
        _dmarc     IN  TXT    "v=DMARC1;p=reject;sp=reject;ruf=mailto:nyarly@gmail.com"
      '';
      */

      sesConfig = import secrets/ses-creds.nix;
    in
    {
      disabledModules = [ "services/web-apps/grocy.nix" ];
      imports = [
        modules/static-site.nix
        modules/app-proxy.nix
        modules/rails-app.nix
        modules/taskserver-acme.nix
        modules/grocy.nix
        modules/pg_upgrade.nix
      ];

      environment.systemPackages = with pkgs; [ neovim fish ];

      deployment.keys = keys;

      fileSystems = {
        "/var/lib" = {
          device = "/dev/xvdf";
          fsType = "ext4";
          # autoFormat = true;
          autoResize = true;
        };
      };

      security.acme = {
        defaults.email = "nyarly@gmail.com";
        acceptTerms = true;
      };

      services = {
        grocy = {
          enable = true;
          hostName = "groceries.madhelm.net";
          # calendar.firstDayOfWeek = 0; # Sunday
        };

        wagthepig = {
          enable = true;
          package = wagthepig;

          # Should come from a "appserver bridge" module
          protocol = "http";
          listenAddress = "localhost";
          listenPort = ports.wagthepig;

          database = {
            adapter = "postgresql";
            database = "wagthepig";
            host = "localhost";
            username = "wagthepig";
            password = ""; # local trust
            encoding = "utf8";
            pool = 5;
          };

          extraEnvironment = {
            SMTP_HOST = "email-smtp.us-west-2.amazonaws.com";
            SMTP_PORT = "587";
            SMTP_USERNAME = sesConfig.user;
            SMTP_PASSWORD = sesConfig.pass;
          };

        };

        fail2ban = {
          enable = true;
          jails = {
            ssh-aggressive =
            ''
            filter   = sshd[mode=aggressive]
            action   = iptables[name=SSH, port=ssh, protocol=tcp]
            logpath  = /var/log/warn
            maxretry = 5
            '';
          };
        };

        postgresql = {
          enable = true;
          package = pkgs.postgresql_13;
          authentication = ''
            local   all             all                                     trust
            host    all             all             127.0.0.1/32            trust
            host    all             all             ::1/128                 trust
            # Allow replication connections from localhost, by a user with the
            # replication privilege.
            local   replication     all                                     trust
            host    replication     all             127.0.0.1/32            trust
            host    replication     all             ::1/128                 trust
          '';
        };

        httpd = {
          enable = true;
          adminAddr = "nyarly@gmail.com";
        };

        nsd = {
          enable = true;

          interfaces = []; # wildcard interface (?)
          zones = {
            "staticweb" = {
              provideXFR = buddyNSServers;
              notify = buddyNSServers;
              # rrlWhitelist = ["all"];

              data = baseDNSZone;
            };
          };

        };

        taskserver= {
          enable = true;
          fqdn = "tasks.madhelm.net";
          listenHost = "0.0.0.0";
          organisations = {
            madhelm.users = [ "judson" ];
          };
        };

        taskserverAcme = {
          enable = true;
        };

        znc = {
          openFirewall = true;
          mutable = false;
          enable = true;
          useLegacyConfig = false;
          modulePackages = with pkgs.zncModules; [ backlog ];
          config = {
            LoadModule = [ "backlog" ];
            User.judson = {
              Admin = true;
              Nick = "judson";
              AltNick = "judson_";
              #LoadModule = [ "chansaver" "controlpanel" ];
              Network.freenode = {
                Server = "chat.freenode.net +6697";
                #LoadModule = [ "simple_away" ];
                LoadModule = [ "sasl" ];
                Chan = {
                  "#nixos" = { Detached = false; };
                };
              };
              Pass.password = import secrets/znc-pass.nix;
            };
          };
        };
      };

      staticWeb = {
        inherit acmeRoot;
        sites = {
          "judsonlester.info" = { docRoot = blog; };
          "madhelm.net"       = { docRoot = blog; };
        };
      };

      appProxy = {
        inherit acmeRoot;
        sites = {
          "wagthepig.com" = {
            backendPort = ports.wagthepig;
            staticBase = wagthepig + "/share/wagthepig/public";
            staticLocations = [ "assets" "system" ];
            zoneData = baseDNSZone + ''
              @                                             IN MX      10 inbound-smtp.us-west-2.amazonaws.com.
              _amazonses                                    IN TXT     OcC8Uz9saTf9WWsl7sFFkx4LKPe33jP7GBBBQ4y1k6E=
              2j6jkg6lfr5tuqofswar3xi4o7ey3243._domainkey   IN CNAME   2j6jkg6lfr5tuqofswar3xi4o7ey3243.dkim.amazonses.com.
              ff2re2lzbypx3pt6huxv5itp6gygfdle._domainkey   IN CNAME   ff2re2lzbypx3pt6huxv5itp6gygfdle.dkim.amazonses.com.
              536itjwezvjiglhoj6balblsrvovp2i2._domainkey   IN CNAME   536itjwezvjiglhoj6balblsrvovp2i2.dkim.amazonses.com.
            '';
          };
        };
      };

      networking.firewall = {
        allowedTCPPorts = [ 22 53 80 443 53589 ];
        allowedUDPPorts = [ 53 ];
      };

      users.users = {
        root.openssh.authorizedKeys.keyFiles = [
          ssh-keys/root-1.pub
          ssh-keys/root-2.pub
        ];
      };
    };
  }
