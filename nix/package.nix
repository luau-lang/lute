{ pkgs, lib, ... }:
let
	pname = "lute";
	version = "1.0.1-nightly.20261006";
	meta = {
		homepage = "https://lute.luau.org/";
		description = "Lute, a standalone runtime for Luau";
		longDescription = ''
			Lute is a standalone runtime for general-purpose programming in [Luau](https://luau.org). It is designed to make it easy
			to write any sort of general-purpose programs in Luau, including manipulating files, making network requests, and even
			developing tooling that directly manipulates Luau scripts. In addition to the runtime, Lute also includes a standard
			library of Luau code, called `std`, that aims to expose a more featureful standard library for general-purpose
			programming beyond just the runtime capabilities.
		'';
		license = lib.licenses.mit;

		platforms = [ "x86_64-linux" "aarch64-linux" ];

		mainProgram = "lute";
	};
	src = pkgs.fetchFromGitHub {
		owner = "luau-lang";
		repo = "lute";
		rev = "v${version}";
		hash = "sha256-xInUyyy9E0s+LBgqWiFj96oCph9MnFOHmnPOfdQ0+n4=";
	};
	nativeBuildInputs = [
		pkgs.cmake
		pkgs.ninja
		pkgs.git
	];

	dependency_hashes = {
		toml-test = "sha256-J5+JO+BrHzje3YmEC9WWA7U6fn+Eye4DQj/knVR+QhE=";
		zlib = "sha256-Sthd9RsydSLaITNlBp6g1X35WKZdS4h7gr0QhRqdGoI=";
		libsodium = "sha256-ZPVzKJZRglZT2EJKqdBu94I4TRrF5sujSglUR64ApWA=";
		libuv = "sha256-ayTk3qkeeAjrGj5ab7wF7vpWI8XWS1EeKKUqzaD/LY0=";
		luau = "sha256-/k9lU9PK+Wsexe1YtZRHrh089EaXx6W3ZbI1wMaVdsM=";
		curl = "sha256-7UGy24Q0Ny+U9hWXV6BzgKc45zkvw+I24GvgyaYsy/I=";
		boringssl = "sha256-JFKQleui4nNmEsx4k5L7xhvEFh3Ne3MEPnHDSRqEwPc=";
		uSockets = "sha256-EXUdkksmJ4NsLl1+fbwfdZGSzh0BHA1Kv1wTyNB3nTk=";
		uWebSockets = "sha256-Ke6gp7VKEjLpkQzpP3ekpxIXR/9xcZlEmTg3dUNT7mQ=";
	};

	tune_files = builtins.filter
		(name: lib.hasSuffix ".tune" name)
		(builtins.attrNames (builtins.readDir ../extern));

	dependencies = map (file:
	let
		dep = (
			builtins.fromTOML(builtins.readFile(../extern + "/${file}"))
		).dependency;
		hash = dependency_hashes.${dep.name} or lib.fakeHash;
	in
	{
		name = dep.name;
		# must be named value for listToAttrs name/value pairing
		value = pkgs.fetchgit {
			url = dep.remote;
			rev = dep.revision;
			hash = hash;
			fetchSubmodules = true;
		};
	})(tune_files);
in
pkgs.stdenv.mkDerivation {
	inherit src pname version meta nativeBuildInputs;

	passthru = builtins.listToAttrs(dependencies) // {
		updateScript = pkgs.nix-update-script {
			attrPath = "lute";
			extraArgs = [ "--flake" "--version=skip" ]
				++ lib.concatMap(dep: [ "--custom-dep" dep.name ])(dependencies);
		};
	};

	postPatch = lib.concatMapStrings(dep: ''
		cp -R ${dep.value} extern/${dep.name}
		chmod -R u+w extern/${dep.name}
	'')(dependencies);

	# https://github.com/luau-lang/lute/blob/a69dde6c141633927a20438ca53cce5757ef1d73/README.md#Manually-building-Lute
	preConfigure = ''
		mkdir -p build
		cmake -G=Ninja -B build \
			-DCMAKE_BUILD_TYPE=Debug \
			-DLUTE_STDLESS=ON

		ninja -C build lute/cli/lute

		./build/lute/cli/lute tools/luthier.luau generate
	'';

	ninjaFlags = [ "Lute.CLI" ];
	cmakeBuildDir = "build";
	cmakeBuildType = "Release";
	cmakeFlags = [
		"-DLUTE_STDLESS=OFF"
	];

	doCheck = false;
	checkPhase = ''
		runHook preCheck

		cmake --build . \
			--target Lute.Test --parallel "$NIX_BUILD_CORES"

		(
			cd ..
			check_phase_homedir="$(mktemp -d "$TMPDIR/lute-bootstrap-godihatethisshit-XXXXXXXXXXXXXXXXXXXXXXXXX")"
			env HOME="$check_phase_homedir" ./build/tests/lute-tests
		)

		lute/cli/lute test

		runHook postCheck
	'';

	installPhase = ''
		runHook preInstall

		install -Dm755 lute/cli/lute "$out/bin/lute"

		runHook postInstall
	'';

	doInstallCheck = true;
	installCheckPhase = ''
		runHook preInstallCheck

		"$out/bin/lute" --version

		runHook postInstallCheck
	'';
}
