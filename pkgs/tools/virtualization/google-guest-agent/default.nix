{ buildGoModule, fetchFromGitHub, fetchpatch, lib, coreutils, makeWrapper
, google-guest-configs, google-guest-oslogin, iproute2, dhcp, procps
}:

buildGoModule rec {
  pname = "guest-agent";
  version = "20230510.00";

  src = fetchFromGitHub {
    owner = "GoogleCloudPlatform";
    repo = pname;
    rev = version;
    sha256 = "sha256-gYmmQzSFP/Ik4m+iYHJZyUyZil9+IXWZ3p0Pl58Uq40=";
  };

  vendorHash = "sha256-ULGpgygBVC4SRLhPiUlZgBH93w84WlNbvq3S7cVHLaQ=";

  patches = [ ./disable-etc-mutation.patch ];

  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    substitute ${./fix-paths.patch} fix-paths.patch \
      --subst-var out \
      --subst-var-by true "${coreutils}/bin/true"
    patch -p1 < ./fix-paths.patch
  '';

  # We don't add `shadow` here; it's added to PATH if `mutableUsers` is enabled.
  binPath = lib.makeBinPath [ google-guest-configs google-guest-oslogin iproute2 dhcp procps ];

  # Skip tests which require networking.
  preCheck = ''
    rm google_guest_agent/wsfc_test.go
  '';

  postInstall = ''
    mkdir -p $out/etc/systemd/system
    cp *.service $out/etc/systemd/system
    install -Dm644 instance_configs.cfg $out/etc/default/instance_configs.cfg

    wrapProgram $out/bin/google_guest_agent \
      --prefix PATH ":" "$binPath"
  '';

  meta = with lib; {
    homepage = "https://github.com/GoogleCloudPlatform/guest-agent";
    description = "Guest Agent for Google Compute Engine";
    license = licenses.asl20;
    platforms = platforms.linux;
    maintainers = with maintainers; [ abbradar ];
  };
}
