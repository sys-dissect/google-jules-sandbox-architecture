import socket, struct, os, random, sys

HOST = "192.168.0.1"

def csum(data):
    if len(data) % 2: data += b"\x00"
    s = sum(struct.unpack("!%dH" % (len(data)//2), data))
    s = (s >> 16) + (s & 0xffff)
    s += s >> 16
    return ~s & 0xffff

def icmp_roundtrip():
    print("=== ICMP echo round-trip with custom payload ===")
    payload = b"OPENCODE_HOST_PROBE:" + os.urandom(6).hex().encode()
    ident = os.getpid() & 0xffff
    hdr = struct.pack("!BBHHH", 8, 0, 0, ident, 1)
    pkt = hdr + payload
    pkt = struct.pack("!BBHHH", 8, 0, csum(pkt), ident, 1) + payload
    s = socket.socket(socket.AF_INET, socket.SOCK_RAW, socket.IPPROTO_ICMP)
    s.settimeout(3)
    s.sendto(pkt, (HOST, 0))
    while True:
        data, addr = s.recvfrom(2048)
        ihl = (data[0] & 0x0f) * 4
        icmp = data[ihl:]
        typ, code, _, rid, rseq = struct.unpack("!BBHHH", icmp[:8])
        rpay = icmp[8:]
        if typ == 0 and rid == ident:
            print(f"reply from {addr[0]} type={typ} code={code} id={rid} seq={rseq}")
            print("sent payload   :", payload.decode())
            print("echoed payload :", rpay.decode(errors="replace"))
            print("MATCH" if rpay == payload else "MISMATCH")
            return
        print("(other icmp)", typ, code, addr)

def dhcp_discover():
    print("\n=== DHCPDISCOVER (host dnsmasq may also serve DHCP) ===")
    xid = random.getrandbits(32)
    mac = bytes.fromhex("0600c0a80002")
    pkt = struct.pack("!BBBBIHH", 1, 1, 6, 0, xid, 0, 0x8000)
    pkt += b"\x00" * 16
    pkt += mac + b"\x00" * 10
    pkt += b"\x00" * 192
    pkt += b"\x63\x82\x53\x63"
    pkt += bytes([53, 1, 1])                # DHCPDISCOVER
    pkt += bytes([55, 4, 1, 3, 6, 15])      # param req
    pkt += bytes([12, 9]) + b"open-codE"    # hostname
    pkt += bytes([255])
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    try:
        s.bind(("0.0.0.0", 68))
    except Exception as e:
        print("bind 68 failed:", e); return
    s.settimeout(4)
    for dst in ("255.255.255.255", HOST):
        try:
            s.sendto(pkt, (dst, 67))
            print(f"sent DISCOVER to {dst}:67 (xid={xid:#x})")
        except Exception as e:
            print("send failed", dst, e)
    try:
        while True:
            data, addr = s.recvfrom(2048)
            if len(data) < 240: continue
            op = data[0]
            rxid = struct.unpack("!I", data[4:8])[0]
            yiaddr = socket.inet_ntoa(data[16:20])
            print(f"reply from {addr[0]}:{addr[1]} op={op} xid={rxid:#x} yiaddr={yiaddr}")
            # find option 53 (message type)
            i = 240
            while i < len(data):
                if data[i] == 255: break
                if data[i] == 0: i += 1; continue
                t, l = data[i], data[i+1]
                if t == 53 and l >= 1: print("dhcp message type =", data[i+2])
                i += 2 + l
            return
    except socket.timeout:
        print("no DHCP reply (host dnsmasq likely DNS-only)")

icmp_roundtrip()
dhcp_discover()
