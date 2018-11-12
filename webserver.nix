let
  acmeRoot = "/var/run/acme-challenges";

  ports = {
    wagthepig = 3000;
  };

  buddyNSServers = [
    "173.244.206.26 NOKEY"
    "88.198.106.11 NOKEY"
    "108.61.224.67 NOKEY"
    "103.6.87.125 NOKEY"
    "185.136.176.247 NOKEY"

    "2607:f0d0:1001:d::100 NOKEY"
    "2a01:4f8:d12:d01::10:100 NOKEY"
    "2001:19f0:6400:8642::3 NOKEY"
    "2403:2500:4000::f3e NOKEY"
    "2a06:fdc0:fade:2f7::1 NOKEY"
  ];
in
  {
    network.description = "Web server";

    webserver = {  config, pkgs, ... }:
    let
      keys = import ./webserver-keys.nix;
      pubIP = config.networking.publicIPv4;
      blog = pkgs.callPackage ./packages/blog/default.nix {};
      wagthepig = pkgs.callPackage ./packages/wagthepig/default.nix {
        masterKey = keys.wagthepig.text;
      };
    in
    {
      imports = [
        ./modules/static-site.nix
        ./modules/app-proxy.nix
        ./modules/rails-app.nix
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

      services = {
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

          secretKeyBase = "testsecret";
        };

        exim = {
          enable = true;
          config = ''
            tls_advertise_hosts =
            acl_smtp_rcpt = local_relay

            begin acl
            local_relay:
              accept host = localhost
          '';
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
          package = pkgs.postgresql100;
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

              data = ''
                $TTL 18000  ; 5 hours
                @ IN SOA  ns1.lrdesign.com. nyarly.gmail.com. (
                    2018052701 ; serial
                    10800      ; refresh (3 hours)
                    3600       ; retry (1 hour)
                    18000      ; expire (5 hours)
                    18000      ; minimum (5 hours)
                )
                               NS       ns1.lrdesign.com.
                               NS       ns2.lrdesign.com.
                               NS       ns3.lrdesign.com.
                               NS       ns4.lrdesign.com.
                               NS       ns5.lrdesign.com.

                               A        ${pubIP}
                               RP     @ nyarly.gmail.com.
                blog           CNAME  @
                gems           CNAME  @
                repos          CNAME  @
                www            CNAME  @
              '';
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
          };
        };
      };

      networking.firewall = {
        allowedTCPPorts = [ 22 53 80 443 ];
        allowedUDPPorts = [ 53 ];
      };
    };
  }
