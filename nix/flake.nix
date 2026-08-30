{
  description = "Development environment for zoot";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { nixpkgs, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            # A long, dense Lisp source file for pretty-printer benchmarks.
            ZOOT_LISP_CORPUS = "${pkgs.sbclPackages.eclector.src}/code/reader/macro-functions.lisp";
            packages = with pkgs; [
              zig_0_16
              zls
              typst
              ocaml
              dune_3
              (sbcl.withPackages (ps: [ ps.eclector ]))
              rustc
              cargo
              rustfmt
              clippy
              git
            ] ++ lib.optionals stdenv.hostPlatform.isLinux [ perf ];
          };
        }
      );
    };
}
