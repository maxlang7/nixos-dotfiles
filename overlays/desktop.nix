final: prev: {
  # Use OpenAI's complete release package to avoid a large Rust build.
  codex = prev.stdenvNoCC.mkDerivation {
    pname = "codex";
    version = "0.167.0";
    src = prev.fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v0.167.0/codex-package-x86_64-unknown-linux-musl.tar.gz";
      sha256 = "3bbf75e83de6b58aed28f2cf6e33ad423ec31fd4700a1457b94be557ea5a7c6e";
    };
    sourceRoot = ".";
    nativeBuildInputs = [ prev.autoPatchelfHook ];
    buildInputs = [ prev.stdenv.cc.cc.lib prev.alsa-lib ];
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -a bin codex-package.json codex-path codex-resources $out/
      runHook postInstall
    '';
    doInstallCheck = true;
    installCheckPhase = ''
      $out/bin/codex --version
      $out/bin/codex-code-mode-host --help >/dev/null
    '';
    meta = prev.codex.meta;
  };
  t3code = prev.t3code.override {
    t3code-unwrapped = prev.t3code.unwrapped.overrideAttrs (finalAttrs: old: {
      # Pin the current stable release without updating unrelated packages.
      version = "0.1.7";
      src = prev.fetchFromGitHub {
        owner = "pingdotgg";
        repo = "t3code";
        tag = "v${finalAttrs.version}";
        hash = "sha256-oQLmDCDuJPNBsf8MHMD2xhMq+CF6L836/PQesM91Clw=";
      };
      pnpmDeps = prev.fetchPnpmDeps {
        pnpm = prev.pnpm_12;
        inherit (finalAttrs) pname version src pnpmWorkspaces;
        fetcherVersion = 5;
        hash = "sha256-o3RujO4r84ncdp75XE6wiiwhbD9DLmZDXgYHjpLCGMA=";
      };
      patches = (old.patches or []) ++ [
        ../artifacts/patches/t3code-shortcuts.patch
      ];
    });
  };
  # Home "feature carousel" painted torn fragments of previously shown
  # album art around each cover (drop-shadow filter + GPU raster).
  feishin = prev.feishin.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ../artifacts/patches/feishin-carousel-shadow.patch
    ];
  });
}
