{ config, stdenv, fetchzip, autoPatchelfHook, buildFHSUserEnv, writeText
, linuxPackages, procps, cpio, which, alsaLib, xorg, pango
}:
let
  inherit (builtins) elem;
  licenseHelpMsg = text: ''
    error: ${text} for Intel Parallel Studio

    Packages that are part of Intel Parallel Studio require a license and acceptance
    of the End User License Agreement (EULA).

    You can purchase a license at
    https://software.intel.com/en-us/parallel-studio-xe

    You can review the EULA at
    https://software.intel.com/en-us/articles/end-user-license-agreement

    Once purchased, you can use your license with the Intel Parallel Studio Nix
    packages using the following methods:

    a) for `nixos-rebuild` you can indicate the license file to use and your
       acceptance of the EULA by adding lines to `nixpkgs.config` in the
       configuration.nix, like so:

         {
           nixpkgs.config.psxe.licenseFile = /home/ledettwy/COM_L___XXXX-XXXXXXXX.lic;
           nixpkgs.config.psxe.licenseType = "cluster";
           nixpkgs.config.psxe.acceptEula = true;
         }

    b) For `nix-env`, `nix-build`, `nix-shell` or any other Nix command you can
       indicate the license file to use and your acceptance of the EULA by adding
       lines to ~/.config/nixpkgs/config.nix, like so:

          {
            psxe.licenseFile = /home/ledettwy/COM_L___XXXX-XXXXXXXX.lic;
            psxe.licenseType = "cluster";
            psxe.acceptEula = true;
          }

    Please note that the license type can be one of "composer", "professional" or
    "cluster";

    '';
  acceptEula = if config.psxe.acceptEula then "accept" else "decline";
  licenseFile = config.psxe.licenseFile or (throw (licenseHelpMsg "missing license file"));
  licenseType' = config.psxe.licenseType or (throw (licenseHelpMsg "missing license type"));
  licenseType =
    if (elem licenseType' [ "composer" "professional" "cluster" ]) then licenseType'
    else throw (licenseHelpMsg "${licenseType'} is not a valid license type");
  installEnv = buildFHSUserEnv
    { name = "install-env";
      targetPkgs = foo: [ stdenv.cc.cc.lib procps cpio which ];
    };
  silent = writeText "silent.cfg" ''
    ACCEPT_EULA=${acceptEula}
    CONTINUE_WITH_OPTIONAL_ERROR=yes
    CONTINUE_WITH_INSTALLDIR_OVERWRITE=yes
    COMPONENTS=ALL
    PSET_MODE=install
    ACTIVATION_LICENSE_FILE=${licenseFile}
    ACTIVATION_TYPE=license_file
    AMPLIFIER_SAMPLING_DRIVER_INSTALL_TYPE=build
    AMPLIFIER_DRIVER_ACCESS_GROUP=vtune
    AMPLIFIER_DRIVER_PERMISSIONS=666
    AMPLIFIER_LOAD_DRIVER=no
    AMPLIFIER_C_COMPILER=${stdenv.cc}
    AMPLIFIER_KERNEL_SRC_DIR=${linuxPackages.kernel}/lib/modules/${linuxPackages.kernel.modDirVersion}/kernel
    AMPLIFIER_MAKE_COMMAND=auto
    AMPLIFIER_INSTALL_BOOT_SCRIPT=no
    AMPLIFIER_DRIVER_PER_USER_MODE=no
    INTEL_SW_IMPROVEMENT_PROGRAM_CONSENT=no
    SIGNING_ENABLED=yes
    ARCH_SELECTED=ALL
    '';
  parallel-studio = stdenv.mkDerivation
    rec
    { name = "intel-parallel-studio-xe-${version}";
      version = "2018_update3";
      src = fetchzip
        { url = "http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/12998/parallel_studio_xe_2018_update3_cluster_edition.tgz";
          sha256 = "1shnav2jfdj124ccmck1ngnjr10q22cya1drij9fis0wy13ja8a3";
        };
      nativeBuildInputs = [ autoPatchelfHook ];
      buildInputs = [ stdenv.cc.cc.lib alsaLib xorg.libX11 pango.out ];
      phases = [ "unpackPhase" "installPhase" "fixupPhase" ];
      installPhase = ''
        cp ${silent} ./silent.cfg;
        echo "PSET_INSTALL_DIR=$out" >> ./silent.cfg;
        ${installEnv}/bin/install-env ./install.sh -s ./silent.cfg;
        '';
    };
in parallel-studio
