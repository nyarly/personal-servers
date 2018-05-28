let
  accessKeyId = "jdl";
  region = "us-west-2";


  ec2 = { resources, ... }:
  {
    deployment = {
      targetEnv = "ec2";
      ec2 = {
        inherit region accessKeyId;
        instanceType = "t2.micro";
        keyPair = resources.ec2KeyPairs.jdl;
        elasticIPv4 = resources.elasticIPs.web;
        securityGroups = with resources.ec2SecurityGroups; [
          serveSSH.name
          serveDNS.name
          serveHTTP.name
          serveHTTPS.name
        ];
      };
    };
  };
in
  {
    webserver = ec2;
    resources = {
      ec2KeyPairs.jdl = {
        inherit region accessKeyId;
      };

      elasticIPs = {
        web = {
          inherit region accessKeyId;
        };
      };

      ec2SecurityGroups = {
        serveSSH = {...}: {
          inherit region accessKeyId;
          rules = [{
            sourceIp = "0.0.0.0/0";
            fromPort = 0;
            toPort = 22;
          }];
        };

        serveDNS = {...}: {
          inherit region accessKeyId;
          rules = [{
            sourceIp = "0.0.0.0/0";
            fromPort = 0;
            toPort = 53;
          }];
        };

        serveHTTP = {...}: {
          inherit region accessKeyId;
          rules = [{
            sourceIp = "0.0.0.0/0";
            fromPort = 0;
            toPort = 80;
          }];
        };

        serveHTTPS = {...}: {
          inherit region accessKeyId;
          rules = [{
            sourceIp = "0.0.0.0/0";
            fromPort = 0;
            toPort = 443;
          }];
        };
      };
    };
  }
