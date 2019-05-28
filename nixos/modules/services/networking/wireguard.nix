{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.networking.wireguard;

  kernel = config.boot.kernelPackages;

  # interface options

  interfaceOpts = { ... }: {

    options = {

      ips = mkOption {
        example = [ "192.168.2.1/24" ];
        default = [];
        type = with types; listOf str;
        description = "The IP addresses of the interface.";
      };

      privateKey = mkOption {
        example = "yAnz5TF+lXXJte14tji3zlMNq+hd2rYUIgJBgB3fBmk=";
        type = with types; nullOr str;
        default = null;
        description = ''
          Base64 private key generated by wg genkey.

          Warning: Consider using privateKeyFile instead if you do not
          want to store the key in the world-readable Nix store.
        '';
      };

      privateKeyFile = mkOption {
        example = "/private/wireguard_key";
        type = with types; nullOr str;
        default = null;
        description = ''
          Private key file as generated by wg genkey.
        '';
      };

      listenPort = mkOption {
        default = null;
        type = with types; nullOr int;
        example = 51820;
        description = ''
          16-bit port for listening. Optional; if not specified,
          automatically generated based on interface name.
        '';
      };

      preSetup = mkOption {
        example = literalExample ''
          ${pkgs.iproute}/bin/ip netns add foo
        '';
        default = "";
        type = with types; coercedTo (listOf str) (concatStringsSep "\n") lines;
        description = ''
          Commands called at the start of the interface setup.
        '';
      };

      postSetup = mkOption {
        example = literalExample ''
          printf "nameserver 10.200.100.1" | ${pkgs.openresolv}/bin/resolvconf -a wg0 -m 0
        '';
        default = "";
        type = with types; coercedTo (listOf str) (concatStringsSep "\n") lines;
        description = "Commands called at the end of the interface setup.";
      };

      postShutdown = mkOption {
        example = literalExample "${pkgs.openresolv}/bin/resolvconf -d wg0";
        default = "";
        type = with types; coercedTo (listOf str) (concatStringsSep "\n") lines;
        description = "Commands called after shutting down the interface.";
      };

      table = mkOption {
        default = "main";
        type = types.str;
        description = ''The kernel routing table to add this interface's
        associated routes to. Setting this is useful for e.g. policy routing
        ("ip rule") or virtual routing and forwarding ("ip vrf"). Both numeric
        table IDs and table names (/etc/rt_tables) can be used. Defaults to
        "main".'';
      };

      peers = mkOption {
        default = [];
        description = "Peers linked to the interface.";
        type = with types; listOf (submodule peerOpts);
      };

      allowedIPsAsRoutes = mkOption {
        example = false;
        default = true;
        type = types.bool;
        description = ''
          Determines whether to add allowed IPs as routes or not.
        '';
      };
    };

  };

  # peer options

  peerOpts = {

    options = {

      publicKey = mkOption {
        example = "xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg=";
        type = types.str;
        description = "The base64 public key the peer.";
      };

      presharedKey = mkOption {
        default = null;
        example = "rVXs/Ni9tu3oDBLS4hOyAUAa1qTWVA3loR8eL20os3I=";
        type = with types; nullOr str;
        description = ''
          Base64 preshared key generated by wg genpsk. Optional,
          and may be omitted. This option adds an additional layer of
          symmetric-key cryptography to be mixed into the already existing
          public-key cryptography, for post-quantum resistance.

          Warning: Consider using presharedKeyFile instead if you do not
          want to store the key in the world-readable Nix store.
        '';
      };

      presharedKeyFile = mkOption {
        default = null;
        example = "/private/wireguard_psk";
        type = with types; nullOr str;
        description = ''
          File pointing to preshared key as generated by wg pensk. Optional,
          and may be omitted. This option adds an additional layer of
          symmetric-key cryptography to be mixed into the already existing
          public-key cryptography, for post-quantum resistance.
        '';
      };

      allowedIPs = mkOption {
        example = [ "10.192.122.3/32" "10.192.124.1/24" ];
        type = with types; listOf str;
        description = ''List of IP (v4 or v6) addresses with CIDR masks from
        which this peer is allowed to send incoming traffic and to which
        outgoing traffic for this peer is directed. The catch-all 0.0.0.0/0 may
        be specified for matching all IPv4 addresses, and ::/0 may be specified
        for matching all IPv6 addresses.'';
      };

      endpoint = mkOption {
        default = null;
        example = "demo.wireguard.io:12913";
        type = with types; nullOr str;
        description = ''Endpoint IP or hostname of the peer, followed by a colon,
        and then a port number of the peer.'';
      };

      persistentKeepalive = mkOption {
        default = null;
        type = with types; nullOr int;
        example = 25;
        description = ''This is optional and is by default off, because most
        users will not need it. It represents, in seconds, between 1 and 65535
        inclusive, how often to send an authenticated empty packet to the peer,
        for the purpose of keeping a stateful firewall or NAT mapping valid
        persistently. For example, if the interface very rarely sends traffic,
        but it might at anytime receive traffic from a peer, and it is behind
        NAT, the interface might benefit from having a persistent keepalive
        interval of 25 seconds; however, most users will not need this.'';
      };

    };

  };

  peerUnit = interfaceName: interfaceCfg: peerCfg:
    let
      peerName = builtins.hashString "md5" peerCfg.publicKey;
    in {
      "wireguard-${interfaceName}-${peerName}" =  {
        description = "WireGuard Peer - ${interfaceName} - ${peerName}";
        requires = [ "wireguard-${interfaceName}.service" ];
        after = [ "wireguard-${interfaceName}.service" ];
        wantedBy = [ "multi-user.target" ];
        environment.DEVICE = interfaceName;
        path = with pkgs; [ kmod iproute wireguard-tools ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        script = let
          wg_setup = assert (peerCfg.presharedKeyFile == null) || (peerCfg.presharedKey == null); # at most one of the two must be set
            let psk = if peerCfg.presharedKey != null then pkgs.writeText "wg-psk" peerCfg.presharedKey else peerCfg.presharedKeyFile;
            in "wg set ${interfaceName} peer ${peerCfg.publicKey}" +
              optionalString (psk != null) " preshared-key ${psk}" +
              optionalString (peerCfg.endpoint != null) " endpoint ${peerCfg.endpoint}" +
              optionalString (peerCfg.persistentKeepalive != null) " persistent-keepalive ${toString peerCfg.persistentKeepalive}" +
              optionalString (peerCfg.allowedIPs != []) " allowed-ips ${concatStringsSep "," peerCfg.allowedIPs}";
          route_setup =
            optionalString (interfaceCfg.allowedIPsAsRoutes != false)
            (concatMapStringsSep "\n"
              (allowedIP:
                "ip route replace ${allowedIP} dev ${interfaceName} table ${interfaceCfg.table}"
              ) peerCfg.allowedIPs);
        in ''
          ${wg_setup}
          ${route_setup}
        '';

        postStop = let
          wg_destroy = ''
            wg set ${interfaceName} peer ${peerCfg.publicKey} remove
          '';
          route_destroy = optionalString (interfaceCfg.allowedIPsAsRoutes != false)
            (concatMapStringsSep "\n"
              (allowedIP:
                "ip route delete ${allowedIP} dev ${interfaceName} table ${interfaceCfg.table}"
            ) peerCfg.allowedIPs);
        in ''
          ${route_destroy}
          ${wg_destroy}
        '';
      };
    };
  interfaceUnit = { interfaceName, interfaceCfg}:
    # exactly one way to specify the private key must be set
    assert (interfaceCfg.privateKey != null) != (interfaceCfg.privateKeyFile != null);
    let
      privKey = if interfaceCfg.privateKeyFile != null
        then interfaceCfg.privateKeyFile
        else pkgs.writeText "wg-key" interfaceCfg.privateKey;
    in {
      "wireguard-${interfaceName}" = {
        description = "WireGuard Tunnel - ${interfaceName}";
        requires = [ "network-online.target" ];
        after = [ "network.target" "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        environment.DEVICE = interfaceName;
        path = with pkgs; [ kmod iproute wireguard-tools ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        script = ''
          ${optionalString (!config.boot.isContainer) "modprobe wireguard"}

          ${interfaceCfg.preSetup}

          ip link add dev ${interfaceName} type wireguard

          ${concatMapStringsSep "\n" (ip:
            "ip address add ${ip} dev ${interfaceName}"
          ) interfaceCfg.ips}

          wg set ${interfaceName} private-key ${privKey} ${
            optionalString (interfaceCfg.listenPort != null) " listen-port ${toString interfaceCfg.listenPort}"}


          ip link set up dev ${interfaceName}

          ${interfaceCfg.postSetup}
        '';

        postStop = ''
          ip link del dev ${interfaceName}
          ${interfaceCfg.postShutdown}
        '';
      };
    };

  generateUnits = interfaceName: interfaceCfg:
    fold
    (peerCfg: col: col // (peerUnit interfaceName interfaceCfg peerCfg))
      (interfaceUnit { inherit interfaceName interfaceCfg; })
      interfaceCfg.peers;
in

{

  ###### interface

  options = {

    networking.wireguard = {

      interfaces = mkOption {
        description = "Wireguard interfaces.";
        default = {};
        example = {
          wg0 = {
            ips = [ "192.168.20.4/24" ];
            privateKey = "yAnz5TF+lXXJte14tji3zlMNq+hd2rYUIgJBgB3fBmk=";
            peers = [
              { allowedIPs = [ "192.168.20.1/32" ];
                publicKey  = "xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg=";
                endpoint   = "demo.wireguard.io:12913"; }
            ];
          };
        };
        type = with types; attrsOf (submodule interfaceOpts);
      };

    };

  };


  ###### implementation

  config = mkIf (cfg.interfaces != {}) {

    boot.extraModulePackages = [ kernel.wireguard ];
    environment.systemPackages = [ pkgs.wireguard-tools ];

    systemd.services = foldl' (x: y: x // y) {} (
      map (name: generateUnits name cfg.interfaces."${name}")
      (builtins.attrNames cfg.interfaces)
    );
  };

}
