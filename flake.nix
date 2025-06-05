{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs, ... }:
    {
      checks.x86_64-linux.example = let
        flake = import ./example/flake.nix;
        outputs = flake.outputs { inherit nixpkgs; nuget-packageslock2nix = self; };
      in outputs.packages.x86_64-linux.default;

      lib = { system, name ? "project", lockfiles ? [] }:
        with builtins;
        let
          pkgs = import nixpkgs { inherit system; };

          externalDeps = lockfile:
          let
            allDeps' = foldl' (a: b: a // b) { } (attrValues lockfile.dependencies);
            allDeps = map (name: { inherit name; } // (getAttr name allDeps')) (attrNames allDeps');
          in
          filter (dep: (hasAttr "contentHash" dep) && (hasAttr "resolved" dep)) allDeps;

          getNuget = { name, resolved, contentHash, ... }: (pkgs.dotnetCorePackages.fetchNupkg {
            pname = name;
            version = resolved;
            hash = "sha512-${contentHash}";
          }).overrideAttrs (old: {
            src = pkgs.fetchurl {
              name = old.src.name;
              url = old.src.url;
              hash = "sha512-${contentHash}";

              downloadToTemp = true;
              postFetch = ''
                mv $downloadedFile file.zip
                ${pkgs.zip}/bin/zip -d file.zip ".signature.p7s"
                mv file.zip $out
              '';
            };
          });
        in
        map getNuget (concatMap (src: externalDeps (fromJSON (readFile src))) lockfiles);
    };
}
