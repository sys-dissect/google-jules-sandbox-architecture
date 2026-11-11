import socket, struct, sys

HOST=("192.168.0.1",53)

def build(qname, qtype, qclass=1, qid=0x4242):
    hdr=struct.pack("!HHHHHH", qid, 0x0100, 1,0,0,0)  # RD=1
    q=b""
    for label in qname.split("."):
        q+=bytes([len(label)])+label.encode()
    q+=b"\x00"+struct.pack("!HH", qtype, qclass)
    return hdr+q

def parse(resp):
    qid, flags, qd, an, ns, ar = struct.unpack("!HHHHHH", resp[:12])
    rcode = flags & 0xf
    out=[f"id={qid:#x} rcode={rcode} ancount={an}"]
    # skip question
    i=12
    def skip_name(i):
        while True:
            l=resp[i]
            if l==0: return i+1
            if l & 0xc0: return i+2
            i+=1+l
    for _ in range(qd): i=skip_name(i); i+=4
    for _ in range(an):
        i=skip_name(i)
        typ,cls,ttl,rdlen=struct.unpack("!HHIH",resp[i:i+10]); i+=10
        rdata=resp[i:i+rdlen]; i+=rdlen
        if typ==1 and rdlen==4: out.append(f"  A {socket.inet_ntoa(rdata)}")
        elif typ==16:
            j=0; txt=b""
            while j<len(rdata): l=rdata[j]; txt+=rdata[j+1:j+1+l]; j+=1+l
            out.append(f"  TXT {txt.decode(errors='replace')}")
        elif typ==5:
            out.append(f"  CNAME (raw {rdlen}b)")
        else:
            out.append(f"  type={typ} rdlen={rdlen}")
    return "\n".join(out)

def recvn(s,n):
    b=b""
    while len(b)<n:
        c=s.recv(n-len(b))
        if not c: raise EOFError
        b+=c
    return b

print("=== persistent DNS-over-TCP session to 192.168.0.1:53 ===")
s=socket.create_connection(HOST,3); s.settimeout(4)
print("connected:", s.getsockname(), "->", HOST)
queries=[
    ("version.bind",16,3),
    ("opencode-dialog-1.devbox-gateway.internal",1,1),
    ("opencode-dialog-2.devbox-gateway.internal",1,1),
]
for idx,(name,typ,cls) in enumerate(queries,1):
    pkt=build(name,typ,cls,qid=0x4200+idx)
    s.sendall(struct.pack("!H",len(pkt))+pkt)
    ln=struct.unpack("!H",recvn(s,2))[0]
    resp=recvn(s,ln)
    print(f"\n[query {idx}] {name} type={typ} class={cls} -> {ln} bytes")
    print(parse(resp))
# prove the same socket is still open by idling briefly
print("\nsocket still open after 3 exchanges:", s.fileno() >= 0)
s.close()
print("session closed by guest")
