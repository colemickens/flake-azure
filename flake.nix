{
  description = "nixos-azure";

  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    cmpkgs = { url = "github:colemickens/nixpkgs/cmpkgs"; };
  };

  outputs = inputs:
    let
      metadata = builtins.fromJSON (builtins.readFile ./latest.json);

      nameValuePair = name: value: { inherit name value; };
      genAttrs = names: f: builtins.listToAttrs (map (n: nameValuePair n (f n)) names);
      forAllSystems = genAttrs [ "x86_64-linux" "i686-linux" "aarch64-linux" ];

      overlay = import ./packages/default.nix;

      pkgsFor = pkgs: system: includeOverlay:
        import pkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = if includeOverlay then [ overlay ] else [];
        };

      mkSystem = system: pkgs_: thing:
        #(pkgsFor pkgs_ system).lib.nixosSystem {
        pkgs_.lib.nixosSystem {
          inherit system;
          modules = [(./. + "/${thing}")];
          specialArgs.inputs = inputs;
        };
    in
    rec {
      devShell = forAllSystems (system:
        let
          nixpkgs_ = (pkgsFor inputs.nixpkgs system true);
        in
          nixpkgs_.mkShell {
            nativeBuildInputs = with nixpkgs_; [
              nixFlakes zstd
              bash cacert cachix
              curl git jq mercurial
              nix-build-uncached
              openssh ripgrep
              #nix-prefetch
              inputs.cmpkgs.legacyPackages.${system}.nix-prefetch

              #azure-cli
              azure-storage-azcopy
              #blobxfer
              #blobporter
            ];
          }
      );

      # TODO:
      examples = (
        let
          system = "x86_64-linux";
          nixpkgs_ = (pkgsFor inputs.nixpkgs system true);
          x = name: (mkSystem system inputs.nixpkgs name).config.system.build;
        in {
          basic = x "examples/basic";
        }
      );

      nixosModules = import ./modules;

      packages = forAllSystems (system:
        (pkgsFor inputs.nixpkgs system true).
          azurePkgs
      );

      container =
        let
          nixpkgs_ = (pkgsFor inputs.nixpkgs  "x86_64-linux" true);
          attrValues = inputs.nixpkgs.lib.attrValues;
        in
          (nixpkgs_.callPackage ./docker/azure-aio {}).uploadScript;

      defaultPackage = forAllSystems (system:
        let
          nixpkgs_ = (pkgsFor inputs.nixpkgs system true);
          attrValues = inputs.nixpkgs.lib.attrValues;
        in
          nixpkgs_.symlinkJoin {
            name = "flake-azure";
            paths = attrValues nixpkgs_.azurePkgs;
          }
      );
    };
}
