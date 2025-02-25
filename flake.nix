{
  description = "Personal servers deployment and config";
  inputs = {
    modernNix.url = "github:nixos/nixpkgs/nixos-24.11";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";

    flake-utils = {
      url = "github:numtide/flake-utils";
    };
    deploy-rs.url = "github:serokell/deploy-rs";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, modernNix, nixpkgs, deploy-rs, flake-utils, sops-nix }@inputs:
    (flake-utils.lib.eachDefaultSystem (system: let

      pkgs = nixpkgs.legacyPackages.${system};

      modern = modernNix.legacyPackages.${system};

      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            modern.nixVersions.stable
            # nixops # RIP
            # Good a place as any to sketch out new approach:
            # attributes here for server(s), which we can use nixos-rebuild --target to deploy
            # * an association between targets and flake attributes makes sense...
            #
            # For provisioning: Terraform, or https://github.com/tweag/tf-ncl
            # tf-ncl would make the config look a lot like(?) existing config
            # ... then we'd need to import state etc.
            git-crypt
            nix-prefetch-git
            deploy-rs.packages.${system}.deploy-rs

            sops
            ssh-to-pgp
            ssh-to-age
            age
          ];

          nativeBuildInputs = [
            sops-nix.packages.${system}.sops-import-keys-hook
          ];
        };
      })) // (let
      system = flake-utils.lib.system.x86_64-linux;

      nodeList = with builtins; let
        nodeDir = readDir ./nodes;
        isDir = dirList: name: (getAttr name dirList) == "directory";
      in filter (isDir nodeDir) (attrNames nodeDir);

      systemConfig = name: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          sops-nix.nixosModules.sops
          (./. + "/nodes/${name}/configuration.nix")
        ];
        specialArgs = {
          inherit inputs;
          localPkgs = self.packages;
        };
      };

      deployConfig = name: {
        hostname = import (./. + "/nodes/${name}/hostname.nix");
        sshUser = "root";
        sshOpts = [ "-i" "~/.ssh/yubi-fd7a96.pub"];
        profiles.system  = {
          user = "root";
          path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.${name};
        };
      };

      configs = aConfig: names:
        builtins.listToAttrs (map (n: { name = n; value = (aConfig n); }) names);
    in {

      nixosConfigurations = configs systemConfig nodeList;

      deploy.nodes = configs deployConfig nodeList;

      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
    });
}
