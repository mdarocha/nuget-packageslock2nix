{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { nixpkgs, ... }:
    rec {
      nugetOrgSource = { url = "https://www.nuget.org/api"; version = "v2";};
      lib = { system, name ? "project", lockfiles ? [], sources ? [ nugetOrgSource ] }:
        with builtins;
        let
          pkgs = import nixpkgs { inherit system; };

          externalDeps = lockfile:
          let
            allDeps' = foldl' (a: b: a // b) { } (attrValues lockfile.dependencies);
            allDeps = map (name: { inherit name; } // (getAttr name allDeps')) (attrNames allDeps');
          in
          filter (dep: (hasAttr "contentHash" dep) && (hasAttr "resolved" dep)) allDeps;

          getNuget = { name, resolved, contentHash, ... }: pkgs.fetchurl {
            name = "${name}.${resolved}.nupkg";
            urls =
                map (source:
                  { v2 = "${source.url}/v2/package/${name}/${resolved}";
                    v3 =
                    "${source.url}/v3/package/${
                        pkgs.lib.strings.toLower "${name}/${resolved}/${name}.${resolved}.nupkg"
                    }";
                  }.${source.version or "v3"}
                 ) sources;

            sha512 = contentHash;

            downloadToTemp = true;
            postFetch = ''
              mv $downloadedFile file.zip
              ${pkgs.zip}/bin/zip -d file.zip ".signature.p7s" || true
              mv file.zip $out
            '';
          };

          joinWithDuplicates = name: deps: pkgs.runCommand name { preferLocalBuild = true; allowSubstitues = false; } ''
            mkdir -p $out
            cd $out
            ${pkgs.lib.concatMapStrings (x: ''
              mkdir -p "$(dirname ${pkgs.lib.escapeShellArg x.name})"
              ln -s -f ${pkgs.lib.escapeShellArg "${x}"} ${pkgs.lib.escapeShellArg x.name}
            '') deps}
          '';
        in
        (joinWithDuplicates "${name}-deps" (map getNuget (concatMap (src: externalDeps (fromJSON (readFile src))) lockfiles)))
        // { sourceFile = null; };
    };
}
