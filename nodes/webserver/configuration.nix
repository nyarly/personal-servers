{ config, pkgs, ... }:
let
  acmeRoot = "/var/lib/acme";

  ports = {
    wagthepig = 3000;
  };

  buddyNSServers = [
    "2604:180:1:92a::3 NOKEY"
    "2602:fafd:902:51::a NOKEY"
    "2604:180:2:4cf::3 NOKEY"
    "2001:19f0:6400:8642::3 NOKEY"
    "2a01:a500:2766::5c3f:d10b NOKEY"
    "192.184.93.99 NOKEY"
    "108.61.224.67 NOKEY"
    "216.73.156.203 NOKEY"
    "107.191.99.111 NOKEY"
    "37.143.61.179 NOKEY"
  ];

  keys = import ../../secrets/webserver-keys.nix;

  wagthepig = pkgs.callPackage ../../packages/wagthepig/default.nix {
    masterKey = keys.wagthepig.text; # XXX ick; another thing to recommend move to "-harder"
  };

  pubIP = "52.40.201.163"; #config.networking.publicIPv4;

  blog = pkgs.callPackage ../../packages/blog/default.nix {};

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
        groceries      CNAME  @
  '';

  sesConfig = import ../../secrets/ses-creds.nix;

  /*
   *    @          IN  TXT    "v=spf1 +a +mx ip4:${pubIP} -all"
   *    @          IN  TXT    "google-site-verification=PdMCpmcPxMhcuIeabkjGH2AcasilKqCatBs98MxkImk"
   *    _domainkey IN  TXT    "o=-\;"
   *    dkim._domainkey IN  TXT ("v=DKIM1\; t=y\; k=rsa\; p="
   *    ${dnsLines secrets/dkim.cert.bare}
   *    )
   *    @          IN  TXT    "v=DMARC1;p=reject;sp=reject;ruf=mailto:nyarly@gmail.com"
   *    _dmarc     IN  TXT    "v=DMARC1;p=reject;sp=reject;ruf=mailto:nyarly@gmail.com"
   *    '';
  */
in
  {
  disabledModules = [
    "services/web-apps/grocy.nix"
    ../../modules/grocy.nix
    ../../modules/pg_upgrade.nix # upgraded to 13 already
  ];
  imports = [
    ../../modules/static-site.nix
    ../../modules/app-proxy.nix
    ../../modules/rails-app.nix
    ../../modules/taskserver-acme.nix
  ];

  # XXX
  nixpkgs.config.permittedInsecurePackages = [
    "ruby-2.7.8"
    "openssl-1.1.1w"
  ];

  sops = {
    defaultSopsFile = ../../sops-secrets/default.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets.wagthepig = {
      owner = "wagthepig";
      group = "wheel";
    };
  };

  environment.systemPackages = with pkgs; [ neovim fish ];

  boot.loader.grub.devices = [ "/dev/xvda" ];

  fileSystems = {
    "/" = {
      label = "nixos";
    };

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
    openssh.enable = true;

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
          Pass.password = import ../../secrets/znc-pass.nix;
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
      ../../ssh-keys/root-1.pub
      ../../ssh-keys/root-2.pub
    ];
  };
}
