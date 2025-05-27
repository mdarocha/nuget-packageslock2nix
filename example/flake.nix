{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nuget-packageslock2nix = {
      url = "github:mdarocha/nuget-packageslock2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nuget-packageslock2nix, ... }: {
    packages.x86_64-linux.default =
      let
        pkgs = import nixpkgs { system = "x86_64-linux"; };
      in
      pkgs.buildDotnetModule {
        pname = "example";
        version = "0.0.1";
        src = ./.;
        nugetDeps = nuget-packageslock2nix.lib {
          system = "x86_64-linux";
          name = "example";
          lockfiles = [
            ./packages.lock.json
          ];
        };
      };

      devShells.x86_64-linux.default = let
        pkgs = import nixpkgs { system = "x86_64-linux"; };
      in
      pkgs.mkShell {
        buildInputs = [
          pkgs.dotnetCorePackages.sdk_8_0
        ];
      };
  };
}
