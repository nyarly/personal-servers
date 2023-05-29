{ pkgs ? import <nixpkgs> {} }:
let
  inherit (pkgs) lib stdenv ruby bundler bundlerEnv;

  rubyEnv = bundlerEnv {
    inherit ruby;

    name = "jekyll-blog";

    gemfile = ./Gemfile;
    lockfile = ./Gemfile.lock;
    gemset = ./gemset.nix;
  };
in
  with builtins; stdenv.mkDerivation {
    name = "blog-jdl";

    src = if pathExists(./source.json) then
    fetchGit (
      fromJSON (readFile ./source.json) //
      {
        url = "git@github.com:nyarly/blog.git";
      }
    )
    else
      pkgs.nix-gitignore.gitignoreSource [] ./.;

    buildInputs = [
      pkgs.bundix
      pkgs.nix-prefetch-git
      rubyEnv
    ];

    buildPhase = "jekyll build";
    installPhase = "cp -a _site $out";
  }
