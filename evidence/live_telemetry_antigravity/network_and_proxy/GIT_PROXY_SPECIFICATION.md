# Git Reverse Proxy Specification (`http://192.168.0.1:8080/`)

## 1. Architectural Role
The host Firecracker gateway (`192.168.0.1`) runs a lightweight HTTP server on port 8080 serving as a transparent reverse proxy between the untrusted microVM guest and GitHub.

```text
[ Guest VM Git Client ]
        │
        │ HTTP (url.http://git@192.168.0.1:8080/.insteadOf https://github.com/)
        ▼
[ Host Gateway: 192.168.0.1:8080 ] (Server: BaseHTTP/0.6 Python/3.12.3)
        │
        │ Attaches Host-Managed GitHub App Installation OAuth Token
        ▼
[ GitHub Edge: api.github.com / github.com ] (Server: GitHub-Babel/3.0, region: iad)
```

---

## 2. Empirical Wire Observations

### Smart HTTP Protocol Advertisement (`info/refs`)
Querying `http://192.168.0.1:8080/<owner>/<repo>.git/info/refs?service=git-upload-pack` returns `200 OK` with standard Git Smart HTTP pkt-line stream:

```text
HTTP/1.0 200 OK
Server: BaseHTTP/0.6 Python/3.12.3
Date: Wed, 04 Nov 2026 11:13:10 GMT
Server: GitHub-Babel/3.0
Content-Type: application/x-git-upload-pack-advertisement
Content-Security-Policy: default-src 'none'; sandbox
X-GitHub-Request-Id: 8300:116AA2:65F223:927BF8:6AEB1346
x-github-edge-region: iad

001e# service=git-upload-pack
000001599f767c5f843b9329878276098bdc297733a96778 HEAD ...
```

### Path-to-Host Translation
Any URL path passed to the proxy translates directly to the upstream GitHub host:
* `http://192.168.0.1:8080/sys-dissect/google-jules-sandbox-architecture` $\rightarrow$ `https://github.com/sys-dissect/google-jules-sandbox-architecture`
* `http://192.168.0.1:8080/google/` $\rightarrow$ `https://github.com/google/`

### Method Constraints
* Supported HTTP Methods: `GET`, `POST`
* Unsupported Methods: `HEAD` (returns `HTTP/1.0 501 Unsupported method ('HEAD')`)

---

## 3. Threat Model & Security Properties
1. **Zero Token In-Guest Footprint**: Untrusted scripts or malware executed inside the Jules coding sandbox cannot scrape GitHub PATs, OAuth tokens, or SSH private keys from files or environment variables; credentials exist exclusively in the host process memory.
2. **Hook Execution Prevention**: The guest global git config enforces `core.hooksPath /dev/null`, preventing a cloned repository from abusing git hooks (`pre-commit`, `post-checkout`) to execute stealth payloads outside the agent's observable FIFO harness.
3. **Branch & Repository Scope Confinement**: Because all push operations go through the proxy, the host can inspect, validate, and restrict which branches the guest is permitted to modify before forwarding to GitHub.
