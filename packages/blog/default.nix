let
  pinned = import ./pinned.nix;
in
  { pkgs ? pinned }:
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
  stdenv.mkDerivation {
    name = "blog-jdl";

    src = if builtins.pathExists(./source.json) then
    builtins.fetchGit (
      let
        source = builtins.fromJSON (builtins.readFile ./source.json);
      in
      {
        url = "git@github.com:nyarly/blog.git";
        inherit (source) rev;
      }
    )
    else
      pkgs.nix-gitignore.gitignoreSource ["_drafts/"] ./.;

    buildInputs = with pkgs; [
      libmysqlclient
      mysql
      bundler
      bundix
      nix-prefetch-git
      rubyEnv
    ];

    buildPhase = "jekyll build";
    installPhase = "cp -a _site $out";
  }
