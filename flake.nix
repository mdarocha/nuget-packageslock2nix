{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { nixpkgs, ... }:
    {
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

          getNuget = { name, resolved, contentHash, ... }: pkgs.dotnetCorePackages.fetchNupkg {
            pname = name;
            version = resolved;
            url = "https://www.nuget.org/api/v2/package/${name}/${resolved}";
            hash = "sha512-${contentHash}";
          };
        in
        map getNuget (concatMap (src: externalDeps (fromJSON (readFile src))) lockfiles);
    };
}
