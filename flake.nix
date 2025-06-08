{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs, ... }:
    {
      checks.x86_64-linux.example =
        let
          flake = import ./example/flake.nix;
          outputs = flake.outputs { inherit nixpkgs; nuget-packageslock2nix = self; };
        in
        outputs.packages.x86_64-linux.default;

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;

      lib = { system, name ? "project", lockfiles ? [ ], excludePackages ? [ ] }:
        let
          pkgs = import nixpkgs { inherit system; };

          inherit (pkgs.lib)
            foldl' attrValues
            getAttr attrNames
            filter hasAttr pipe
            readFile elem;
          inherit (pkgs.lib.lists) concatMap;
          inherit (pkgs.lib.strings) fromJSON;

          externalDeps = lockfile:
            let
              allDeps' = foldl' (a: b: pkgs.lib.recursiveUpdate a b) { } (attrValues lockfile.dependencies);
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
        pipe
          (concatMap
            (src: pipe src [
              readFile
              fromJSON
              externalDeps
            ])
            lockfiles) [
          (filter (dep:
            !(elem "${dep.name}-${dep.resolved}" excludePackages)
          ))
          (map getNuget)
        ];
    };
}
