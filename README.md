# nuget-packageslock2nix

A nix flake that contains a helper function to automatically
download NuGet dependencies of .NET projects based on its lock file,
without having to generate a `deps.nix` file.

Indented for use with projects built using [`buildDotnetModule`](https://nixos.org/manual/nixpkgs/stable/#dotnet).

## How it works

[Package locks](https://devblogs.microsoft.com/nuget/enable-repeatable-package-restores-using-a-lock-file/) are
a relatively new NuGet feature, similar to `package-lock.json` in `npm`.

To enable it, you have to set the proper MSBuild property in your `.csproj` files:

```csproj
<PropertyGroup>
    <RestorePackagesWithLockFile>true</RestorePackagesWithLockFile>
</PropertyGroup>
```

After setting, running `dotnet restore` will generate a `packages.lock.json` file for
every project. This file represents an exact list of all packages that were restored as
dependencies of the given project, and should be committed to source control.

Crucially, every package in the file contains a field named `contentHash`, which contains a
_hash_ of the exact package that was downloaded from NuGet.

Having this hash allows us to deterministically fetch a list of packages in Nix.
Without this lock file we don't have a native way to get package hashes, that's why
we normally have to generate a `deps.nix` file using `fetch-deps`.

There's one catch, in that the `contentHash` doesn't represent the hash of the _exact_ package
that was downloaded, but of a package without it's signature (which may differ even with the same package
contents). That's why, when downloading the package, we remove its signature file - this causes
the `contentHash` to match the hash of the actual `.nupkg` file.

## How to use it

First, make sure your project has package locks setup and committed.

Then, use the `lib` output of this flake, passing the following variables:

- `system` - the identifier of the system this is running on.
- `name` - optional, sets the name of the project in the generated derivation
- `lockfiles` - a list of all lockfiles in the project to use

### Example

See the [`example`](./example) folder for an example of usage.

### Filtering packages

It may be necessary to filter out some packages from the list of dependencies.

For example, when a conflict occurs with the existing nixpkgs' `dotnet-sdk.packages`,
which is implicitly added by `buildDotnetModule`, the following error may occur:

```
> Running phase: patchPhase
> Running phase: configureNuget
> ln: failed to create symbolic link '/build/nuget.VAABYb/fallback/microsoft.net.illink.tasks/8.0.16': File exists
```

To work around that, specify the packages that cause conflicts in the `excludePackages` field.

This field can be set to an list of package `name`s (`pname` and `version` joined by `-`).
