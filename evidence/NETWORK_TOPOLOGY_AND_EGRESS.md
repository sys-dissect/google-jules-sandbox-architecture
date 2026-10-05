# Network Topology, Routing, and Public Egress Deep Dive

## 1. Public Egress & Geolocation Audit

HTTP and STUN probes confirm the public IP and cloud provenance of the Jules devbox:

```json
{
  "ip": "34.72.116.213",
  "country": "United States",
  "region_name": "Iowa",
  "city": "Council Bluffs",
  "asn": "AS396982",
  "asn_org": "GOOGLE-CLOUD-PLATFORM",
  "hostname": "213.116.72.34.bc.googleusercontent.com"
}
```

### Analysis
* **Cloud Origin:** Jules devboxes run inside Google Cloud Platform's `us-central1` datacenter region (Council Bluffs, Iowa).
* **Autonomous System:** `AS396982` (`GOOGLE-CLOUD-PLATFORM`).
* **NAT Gateway:** Outbound traffic exits via Google Cloud NAT / default internet gateway.

---

## 2. Interface Parameters & MAC Derivation

```bash
$ ip -d link show eth0
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP mode DEFAULT group default qlen 1000
    link/ether 06:00:c0:a8:00:02 brd ff:ff:ff:ff:ff:ff promiscuity 0 allmulti 0 minmtu 68 maxmtu 65535 addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 tso_max_size 65536 tso_max_segs 65535 gro_max_size 65536 parentbus virtio parentdev virtio2
```

### Analysis
* **MAC Address Encoding:** `06:00:c0:a8:00:02`.
  * The last four octets `c0:a8:00:02` correspond to the IPv4 address `192.168.0.2` in hexadecimal:
    * `0xc0` = 192
    * `0xa8` = 168
    * `0x00` = 0
    * `0x02` = 2
  * This is a signature pattern of Firecracker's static network device generation.
* **Segmentation Offloading:** TSO and GSO max sizes are set to 65536 bytes (`gro_max_size 65536`), maximizing throughput over the Virtio-Net virtual ring.

---

## 3. Firewall & Netfilter Rules

```bash
$ sudo iptables -S
-P INPUT ACCEPT
-P FORWARD DROP
-P OUTPUT ACCEPT
-N DOCKER
-N DOCKER-BRIDGE
-N DOCKER-CT
-N DOCKER-FORWARD
-N DOCKER-INTERNAL
-N DOCKER-USER
-A FORWARD -j DOCKER-USER
-A FORWARD -j DOCKER-FORWARD
-A DOCKER ! -i docker0 -o docker0 -j DROP
-A DOCKER-BRIDGE -o docker0 -j DOCKER
-A DOCKER-CT -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A DOCKER-FORWARD -j DOCKER-CT
-A DOCKER-FORWARD -j DOCKER-INTERNAL
-A DOCKER-FORWARD -j DOCKER-BRIDGE
-A DOCKER-FORWARD -i docker0 -j ACCEPT
```

### Analysis
* Default in-guest firewall policies are wide open (`INPUT ACCEPT`, `OUTPUT ACCEPT`).
* All custom iptables chains are populated automatically by the local `dockerd` service for `docker0` bridge NAT (`172.17.0.0/16`).
* No restrictive outbound packet filters or firewall policies are enforced from inside the guest.
