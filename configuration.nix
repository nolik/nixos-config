# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  #sops
  sops.defaultSopsFile = ./secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  
  sops.age.keyFile = "/home/nolik/.config/sops/age/keys.txt";
  
  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  networking.hostName = "nix-server"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
 # Wake Up on Lan
  networking.interfaces.enp3s0.wakeOnLan.enable = true;

 # networking = {
   # wireless.enable = true;
   # wireless.interfaces = [ "wlp2s0" ];
   # wireless.networks = {
   #    "SSID" = {
   #      psk = "password";
   #    };
   # };
 # };

  # Set your time zone.
  time.timeZone = "Europe/Warsaw";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pl_PL.UTF-8";
    LC_IDENTIFICATION = "pl_PL.UTF-8";
    LC_MEASUREMENT = "pl_PL.UTF-8";
    LC_MONETARY = "pl_PL.UTF-8";
    LC_NAME = "pl_PL.UTF-8";
    LC_NUMERIC = "pl_PL.UTF-8";
    LC_PAPER = "pl_PL.UTF-8";
    LC_TELEPHONE = "pl_PL.UTF-8";
    LC_TIME = "pl_PL.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "us";

  # samba group
  users.groups.samba = {};

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.nolik = {
    isNormalUser = true;
    description = "nolik";
    extraGroups = [ "networkmanager" "wheel" "samba"];
    packages = with pkgs; [];
  };

  sops.secrets.smb.neededForUsers = true;
  sops.secrets.smb-plaintext.neededForUsers = true;
  users.users.smb = {
    description = "Write-access to samba media shares";
    # Add this user to a group with permission to access the expected files 
    extraGroups = [ "samba" ];
    # Password can be set in clear text with a literal string or from a file.
    # Using sops-nix we can use the same file so that the system user and samba
    # user share the same credential (if desired).
    hashedPasswordFile = config.sops.secrets.smb.path;
    isNormalUser = true;
  };

  # Enable automatic login for the user.
  services.getty.autologinUser = "nolik";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
   
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    helix    
    git
    # wget
  ];

  environment.variables.EDITOR = "hx";

  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "smb";
        "netbios name" = "smb";
        "security" = "user";
        #"use sendfile" = "yes";
        #"max protocol" = "smb2";
        # note: localhost is the ipv6 localhost ::1
        "hosts allow" = "192.168.10. 127.0.0.1 localhost";
        "hosts deny" = "0.0.0.0/0";
        "guest account" = "nobody";
        "map to guest" = "bad user";
      };
      "share" = {
        "path" = "/mnt/share";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "smb";
        "force group" = "samba";
        "valid user" = "smb";
      };
    };
  };
  
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };
  
  services.avahi = {
    publish.enable = true;
    publish.userServices = true;
    # ^^ Needed to allow samba to automatically register mDNS records (without the need for an `extraServiceFile`
    nssmdns4 = true;
    # ^^ Not one hundred percent sure if this is needed- if it aint broke, don't fix it
    enable = true;
    openFirewall = true;
  };

  # Activation scripts run every time nixos switches build profiles. So if you're
  # pulling the user/samba password from a file then it will be updated during
  # nixos-rebuild. Again, in this example we're using sops-nix with a "samba" entry
  # to avoid cleartext password, but this could be replaced with a static path.
  system.activationScripts = {
    # The "init_smbpasswd" script name is arbitrary, but a useful label for tracking
    # failed scripts in the build output. An absolute path to smbpasswd is necessary
    # as it is not in $PATH in the activation script's environment. The password
    # is repeated twice with newline characters as smbpasswd requires a password
    # confirmation even in non-interactive mode where input is piped in through stdin. 
    init_smbpasswd.text = ''
      /run/current-system/sw/bin/printf "$(/run/current-system/sw/bin/cat ${config.sops.secrets.smb-plaintext.path})\n$(/run/current-system/sw/bin/cat ${config.sops.secrets.smb-plaintext.path})\n" | /run/current-system/sw/bin/smbpasswd -sa smb
    '';
  };

  # List services that you want to enable:
   services.logind.settings.Login = {
    # don’t shutdown when power button is short-pressed
      HandleLidSwitch = "ignore";
      HandleLidSwitchDocked = "ignore";
      HandleLidSwitchExternalPower = "ignore";
    };
    # '';

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;


  # Cron jobs
  systemd.timers.shutdown-at-23 = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "23:00";
    };
  };

  systemd.services.shutdown-at-23 = {
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/run/current-system/sw/bin/systemctl poweroff";
    };
  };


  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 22 445 ];
  networking.firewall.allowPing = true;
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

}
