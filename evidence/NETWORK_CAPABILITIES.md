# Network Capabilities Probe

## 1. TUN device
```bash
$ ls -l /dev/net/tun; ip tuntap list 2>&1
crw-rw-rw- 1 root root 10, 200 Mar  6  2026 /dev/net/tun
```

## 2. UDP egress
```bash
$ nc -z -v -u -w 3 8.8.8.8 53 2>&1 || echo "UDP 53 failed"
Connection to 8.8.8.8 53 port [udp/domain] succeeded!
```

## 3. Non-standard TCP egress
```bash
$ nc -z -v -w 3 portquiz.net 8080 2>&1 || echo "TCP 8080 failed"
Connection to portquiz.net (35.180.139.74) 8080 port [tcp/http-alt] succeeded!
```
