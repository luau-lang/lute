{ pkgs, dev_packages ? [], lute }:
pkgs.mkShell {
	name = "Lute Development Env";
	inputsFrom = [
		lute
	];
	packages = dev_packages ++ [
		pkgs.clang-tools
		pkgs.cmake
		pkgs.ninja
		pkgs.git
		lute
	];
}
