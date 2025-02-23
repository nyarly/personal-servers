{
  description = "Personal servers deployment and config";
  inputs = {
    systems.url = "github:nix-systems/x86_64-linux";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    deploy-rs.url = "github:serokell/deploy-rs";
  };
  outputs = { self, nixpkgs, flake-utils, deploy-rs, systems }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        deployPkgs = import nixpkgs {
          inherit system;
          overlays = [
            deploy-rs.overlay # or deploy-rs.overlays.default
            (self: super: {
              deploy-rs = { inherit (pkgs) deploy-rs; lib = super.deploy-rs.lib;
              }; })
          ];
        };

      in {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixVersions.nix_2_17
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
            deployPkgs.deploy-rs.deploy-rs
         ];
        };
      });
}
