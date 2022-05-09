{ nixpkgs ? <nixpkgs>
, systems ? [ "x86_64-linux" "x86_64-darwin" ]
}:

let
  pkgs = import nixpkgs {};
in
rec {
  build = pkgs.lib.genAttrs systems (system:
    let
      pkgs = import nixpkgs { inherit system; };
    in
    pkgs.runCommand "gitlike-rsync" {} ''
      mkdir -p $out/bin
      sed -e "s|/bin/bash|${pkgs.stdenv.shell}|" \
        -e "s|getopt|${pkgs.getopt}/bin/getopt|" \
        -e "s|sed |${pkgs.gnused}/bin/sed |" \
        ${./gitlike-rsync} > $out/bin/gitlike-rsync
      chmod +x $out/bin/gitlike-rsync
    ''
  );

  tests = import ./tests.nix {
    inherit nixpkgs;
    gitlike-rsync = builtins.getAttr builtins.currentSystem build;
  };
}
