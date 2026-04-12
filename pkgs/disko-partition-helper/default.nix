{ pkgs }:

pkgs.writeShellApplication {
  name = "disko-partition-helper";

  runtimeInputs = with pkgs; [
    gum
    jq
    util-linux
    coreutils
  ];

  text = ''
    set -e

    # Check if run as root, unless in test mode
    if [ "''${ALLOW_LOOP:-0}" -ne 1 ] && [ "$(id -u)" -ne 0 ]; then
      echo "This script must be run as root to detect disks correctly."
      exit 1
    fi

    TARGET_TYPE="disk"
    if [ "''${ALLOW_LOOP:-0}" -eq 1 ]; then
        TARGET_TYPE="loop"
        echo "🧪 TEST MODE: Scanning for loop devices instead of physical disks..."
    fi

    echo "Scanning for disks..."
    DISKS_JSON=$(lsblk -d -n -o NAME,SIZE,TYPE -J | jq -c --arg type "$TARGET_TYPE" '[.blockdevices[] | select(.type == $type)]')
    
    if [ "$(echo "$DISKS_JSON" | jq 'length')" -eq 0 ]; then
      gum style --foreground 196 "No disks found!"
      exit 1
    fi

    DISK_CHOICES=$(echo "$DISKS_JSON" | jq -r '.[] | "\(.name) (\(.size))"')

    echo "Select disk(s) to partition (Space to select, Enter to confirm):"
    SELECTED_LINES=$(echo "$DISK_CHOICES" | gum choose --no-limit --height 10 --header "Select Disks")

    if [ -z "$SELECTED_LINES" ]; then
      gum style --foreground 196 "No disks selected. Exiting."
      exit 1
    fi

    SELECTED_DEVICES=()
    while IFS= read -r line; do
      dev=$(echo "$line" | awk '{print $1}')
      SELECTED_DEVICES+=("$dev")
    done <<< "$SELECTED_LINES"

    DISK_COUNT=''${#SELECTED_DEVICES[@]}
    gum style --foreground 76 "Selected $DISK_COUNT disk(s): ''${SELECTED_DEVICES[*]}"

    # Select Layout
    gum style --foreground 214 "Choose Partition Layout:"
    LAYOUT=$(gum choose "standard (Root on Disk)" "impermanence (Root on tmpfs/RAM)")

    RAID_MODE="single"
    if [ "$DISK_COUNT" -gt 1 ]; then
      gum style --foreground 214 "Multiple disks selected. Choose RAID mode (using mdadm + btrfs):"
      RAID_MODE=$(gum choose "raid0" "raid1")
    fi

    gum confirm "This will generate a disko configuration for:
    Disks: ''${SELECTED_DEVICES[*]}
    Layout: $LAYOUT
    Mode: $RAID_MODE
    
    WARNING: Applying this configuration will WIPE ALL DATA on these disks!
    Continue?" || exit 1

    OUTPUT_FILE="disko-config.nix"

    # Helper function for Btrfs content (Applied to the Filesystem)
    btrfs_content() {
      if [[ "$LAYOUT" == *"standard"* ]]; then
        cat <<INNER_EOF
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "/root" = {
                  mountpoint = "/";
                };
                "/home" = {
                  mountpoint = "/home";
                };
                "/nix" = {
                  mountpoint = "/nix";
                };
              };
INNER_EOF
      else
        # Impermanence Layout
        cat <<INNER_EOF
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "/nix" = {
                  mountpoint = "/nix";
                  mountOptions = [ "compress=zstd" "noatime" ];
                };
                "/persist" = {
                  mountpoint = "/persist";
                  mountOptions = [ "compress=zstd" "noatime" ];
                };
              };
INNER_EOF
      fi
    }

    # Helper function for ESP partition
    # $1: "boot" (mount it) or "backup" (don't mount)
    esp_partition() {
      MOUNT_CONFIG=""
      if [ "$1" == "boot" ]; then
        MOUNT_CONFIG='mountpoint = "/boot"; mountOptions = [ "umask=0077" ];'
      fi
      
      cat <<INNER_EOF
              ESP = {
                size = "512M";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  $MOUNT_CONFIG
                };
              };
INNER_EOF
    }

    cat <<EOF > "$OUTPUT_FILE"
    {
      disko.devices = {
EOF

    if [ "$RAID_MODE" = "single" ]; then
        # === SINGLE DISK MODE ===
        DEV="''${SELECTED_DEVICES[0]}"
        cat <<EOF >> "$OUTPUT_FILE"
        disk = {
          main = {
            type = "disk";
            device = "/dev/$DEV";
            content = {
              type = "gpt";
              partitions = {
                $(esp_partition "boot")
                root = {
                  size = "100%";
                  content = {
                    $(btrfs_content)
                  };
                };
              };
            };
          };
        };
EOF
    else
        # === MDADM RAID MODE ===
        # Map raid mode to mdadm level
        if [ "$RAID_MODE" = "raid0" ]; then LEVEL=0; else LEVEL=1; fi

        cat <<EOF >> "$OUTPUT_FILE"
        disk = {
EOF

        for i in "''${!SELECTED_DEVICES[@]}"; do
          DEV="''${SELECTED_DEVICES[$i]}"
          DISK_ID="disk$((i+1))"
          
          # Determine ESP Type: First disk gets /boot, others get backup
          ESP_TYPE="backup"
          if [ "$i" -eq 0 ]; then ESP_TYPE="boot"; fi

          cat <<EOF >> "$OUTPUT_FILE"
          $DISK_ID = {
            type = "disk";
            device = "/dev/$DEV";
            content = {
              type = "gpt";
              partitions = {
                $(esp_partition "$ESP_TYPE")
                raid = {
                  size = "100%";
                  content = {
                    type = "mdraid";
                    name = "root";
                  };
                };
              };
            };
          };
EOF
        done

        cat <<EOF >> "$OUTPUT_FILE"
        };
        mdadm = {
          root = {
            type = "mdadm";
            level = $LEVEL;
            content = {
              $(btrfs_content)
            };
          };
        };
EOF
    fi

    cat <<EOF >> "$OUTPUT_FILE"
      };
    }
EOF

    gum style --foreground 76 "Configuration written to $OUTPUT_FILE"
  '';
}
