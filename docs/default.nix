{
  pkgs,
  # Note, this should be "the standard library" + PM extensions.
  lib ? import ../modules/lib/stdlib-extended.nix pkgs.lib,
  release,
  isReleaseBranch,
}: let
  nmdSrc = fetchTarball {
    url = "https://git.sr.ht/~rycee/nmd/archive/824a380546b5d0d0eb701ff8cd5dbafb360750ff.tar.gz";
    sha256 = "0vvj40k6bw8ssra8wil9rqbsznmfy1kwy7cihvm13rajwdg9ycgg";
  };

  nmd = import nmdSrc {
    inherit lib;
    # The DocBook output of `nixos-render-docs` doesn't have the change
    # `nmd` uses to work around the broken stylesheets in
    # `docbook-xsl-ns`, so we restore the patched version here.
    pkgs =
      pkgs
      // {
        docbook-xsl-ns =
          pkgs.docbook-xsl-ns.override {withManOptDedupPatch = true;};
      };
  };

  # Make sure the used package is scrubbed to avoid actually
  # instantiating derivations.
  scrubbedPkgsModule = {
    imports = [
      {
        _module.args = {
          pkgs = lib.mkForce (nmd.scrubDerivations "pkgs" pkgs);
          pkgs_i686 = lib.mkForce {};
        };
      }
    ];
  };

  dontCheckDefinitions = {_module.check = false;};

  gitHubDeclaration = user: repo: subpath: let
    urlRef =
      if isReleaseBranch
      then "release-${release}"
      else "master";
  in {
    url = "https://github.com/${user}/${repo}/blob/${urlRef}/${subpath}";
    name = "<${repo}/${subpath}>";
  };

  pmPath = toString ./..;

  buildOptionsDocs = args @ {
    modules,
    includeModuleSystemOptions ? true,
    ...
  }: let
    options = (lib.evalModules {inherit modules;}).options;
  in
    pkgs.buildPackages.nixosOptionsDoc ({
        options =
          if includeModuleSystemOptions
          then options
          else builtins.removeAttrs options ["_module"];
        transformOptions = opt:
          opt
          // {
            # Clean up declaration sites to not refer to the Project Manager
            # source tree.
            declarations = map (decl:
              if lib.hasPrefix pmPath (toString decl)
              then
                gitHubDeclaration "sellout" "project-manager"
                (lib.removePrefix "/" (lib.removePrefix pmPath (toString decl)))
              else if decl == "lib/modules.nix"
              then
                # TODO: handle this in a better way (may require upstream
                # changes to nixpkgs)
                gitHubDeclaration "NixOS" "nixpkgs" decl
              else decl)
            opt.declarations;
          };
      }
      // builtins.removeAttrs args ["modules" "includeModuleSystemOptions"]);

  pmOptionsDocs = buildOptionsDocs {
    modules =
      import ../modules/all-modules.nix {
        inherit lib pkgs;
        check = false;
        modules = builtins.attrValues (import ../modules/modules.nix);
      }
      ++ [scrubbedPkgsModule];
    variablelistId = "project-manager-options";
  };

  docs = nmd.buildDocBookDocs {
    pathName = "project-manager";
    projectName = "Project Manager";
    modulesDocs = [
      {
        docBook = pkgs.linkFarm "pm-module-docs-for-nmd" {
          "nmd-result/project-manager-options.xml" = pmOptionsDocs.optionsDocBook;
        };
      }
    ];
    documentsDirectory = ./.;
    documentType = "book";
    chunkToc = ''
      <toc>
        <d:tocentry xmlns:d="http://docbook.org/ns/docbook" linkend="book-project-manager-manual"><?dbhtml filename="index.html"?>
          <d:tocentry linkend="ch-options"><?dbhtml filename="options.html"?></d:tocentry>
          <d:tocentry linkend="ch-nixos-options"><?dbhtml filename="nixos-options.html"?></d:tocentry>
          <d:tocentry linkend="ch-nix-darwin-options"><?dbhtml filename="nix-darwin-options.html"?></d:tocentry>
          <d:tocentry linkend="ch-tools"><?dbhtml filename="tools.html"?></d:tocentry>
          <d:tocentry linkend="ch-release-notes"><?dbhtml filename="release-notes.html"?></d:tocentry>
        </d:tocentry>
      </toc>
    '';
  };
in {
  inherit nmdSrc;

  options = {
    # TODO: Use `pmOptionsDocs.optionsJSON` directly once upstream
    # `nixosOptionsDoc` is more customizable.
    json =
      pkgs.runCommand "options.json" {
        meta.description = "List of Project Manager options in JSON format";
      } ''
        mkdir -p $out/{share/doc,nix-support}
        cp -a ${pmOptionsDocs.optionsJSON}/share/doc/nixos $out/share/doc/project-manager
        substitute \
          ${pmOptionsDocs.optionsJSON}/nix-support/hydra-build-products \
          $out/nix-support/hydra-build-products \
          --replace \
            '${pmOptionsDocs.optionsJSON}/share/doc/nixos' \
            "$out/share/doc/project-manager"
      '';
  };

  manPages = docs.manPages;

  manual = {inherit (docs) html htmlOpenTool;};

  # Unstable, mainly for CI.
  jsonModuleMaintainers = pkgs.writeText "pm-module-maintainers.json" (let
    result = lib.evalModules {
      modules =
        import ../modules/modules.nix {
          inherit lib pkgs;
          check = false;
        }
        ++ [scrubbedPkgsModule];
    };
  in
    builtins.toJSON result.config.meta.maintainers);
}
