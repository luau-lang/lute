{
	description = "provides lute development shell & nix package";

	inputs = {
		nixpkgs = {
			url = "github:NixOS/nixpkgs/nixos-unstable";
		};
	};

	outputs =
	{
		self,
		nixpkgs
	}:
	let
		systemAttrs = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];

		forSystems = fun: systemAttrs (system: fun {
			pkgs = import nixpkgs { inherit system; };
			inherit system;
		});
	in
	{
		packages = forSystems ({ pkgs, system }: let
			package = pkgs.callPackage ./nix/package.nix { inherit pkgs system; };
		in
		{
			default = package;
			lute = package;
		});

		devShells = forSystems ({ pkgs, system }: {
			default = pkgs.callPackage ./nix/dev_shell.nix {
				lute = self.packages.${system}.default;
				inherit pkgs;
			};
		});
	};
}
