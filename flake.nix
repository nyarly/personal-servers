{
  description = "versiontool";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
  flake-utils.lib.eachDefaultSystem (system:
  let pkgs = nixpkgs.legacyPackages.${system};
  in {
    devShell = pkgs.mkShell {
      buildInputs = with pkgs; [
        nixops
        git-crypt
        nix-prefetch-git
      ];
    };
  });
}
