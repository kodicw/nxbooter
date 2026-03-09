{ ... }:
{
  buildNxbooter =
    {
      pkgs,
      systemConfig,
    }:
    let
      build = systemConfig.config.system.build;
    in
    pkgs.writeShellScriptBin "run-pixiecore" ''
      exec ${pkgs.pixiecore}/bin/pixiecore \
        boot ${build.kernel}/bzImage ${build.initialRamdisk}/initrd \
        --cmdline "init=${build.toplevel}/init loglevel=4" \
        --debug \
        --port 64172 --status-port 64172 "$@"
    '';
  buildBtrfsRaid =
    {
      mainDisk,
      extraDisks,
      raidLevel,
    }:
    {
      disko.devices = {
        disk = {
          storage = {
            type = "disk";
            device = "${mainDisk}";
            content = {
              type = "gpt";
              partitions = {
                root = {
                  size = "100%";
                  content = {
                    type = "btrfs";
                    extraArgs = [
                      "--force"
                      "--data ${raidLevel}"
                      "--metadata ${raidLevel}"
                    ]
                    ++ extraDisks;
                    subvolumes = {
                      "/persistent" = {
                        mountOptions = [ "compress=zstd" ];
                        mountpoint = "/persistent";
                      };
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
}
