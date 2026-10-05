# Runtime Toolchain Audit

## 1. Toolchain audit execution
```bash
$ /opt/environment_summary.sh
-------------------------------------
Environment check starting...

--------- Python ---------
✅  python3: Python 3.12.13
✅  python: Python 3.12.13
✅  pip: pip 26.0.1 from /home/jules/.pyenv/versions/3.12.13/lib/python3.12/site-packages/pip (python 3.12)
✅  pipx: 1.4.3
✅  poetry: Poetry (version 2.3.2)
✅  uv: uv 0.10.8
✅  black: black, 26.1.0 (compiled: yes)
Python (CPython) 3.12.3
✅  mypy: mypy 1.19.1 (compiled: yes)
✅  pytest: pytest 9.0.2
✅  ruff: ruff 0.15.5
✅  pyenv: available
  system
  3.10.20
* 3.12.13 (set by /home/jules/.pyenv/version)

--------- NodeJS ---------
✅  node: v22.22.1
/opt/environment_summary.sh: line 64: nvm: command not found
❌  nvm: not found
✅  npm: 11.11.0
✅  yarn: 1.22.22
✅  pnpm: 10.30.3
✅  eslint: v10.0.2
✅  prettier: 3.8.1
✅  chromedriver: ChromeDriver 146.0.7680.66 (8074df26380b9303d287ee8ae2abec0b73bef9d7-refs/branch-heads/7680@{#1899})

--------- Java ---------
✅  java: openjdk version "21.0.10" 2026-01-20
OpenJDK Runtime Environment (build 21.0.10+7-Ubuntu-124.04)
OpenJDK 64-Bit Server VM (build 21.0.10+7-Ubuntu-124.04, mixed mode, sharing)
✅  mvn: Apache Maven 3.9.12 (848fbb4bf2d427b72bdb2471c22fced7ebd9a7a1)
Maven home: /usr/share/maven
Java version: 21.0.10, vendor: Ubuntu, runtime: /usr/lib/jvm/java-21-openjdk-amd64
Default locale: en, platform encoding: UTF-8
OS name: "linux", version: "6.8.0", arch: "amd64", family: "unix"
✅  gradle: Gradle 8.8

--------- Go ---------
✅  go: go version go1.24.3 linux/amd64

--------- Rust ---------
✅  rustc: rustc 1.94.0 (4a4ef493e 2026-03-02)
✅  cargo: cargo 1.94.0 (85eff7c80 2026-01-15)

--------- Bun ---------
✅  bun: 1.2.14

--------- C/C++ Compilers ---------
✅  clang: Ubuntu clang version 18.1.3 (1ubuntu1)
Target: x86_64-pc-linux-gnu
Thread model: posix
InstalledDir: /usr/bin
✅  gcc: gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0
Copyright (C) 2023 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

✅  cmake: cmake version 3.28.3

CMake suite maintained and supported by Kitware (kitware.com/cmake).
✅  ninja: 1.11.1
✅  conan: Conan version 2.26.2

--------- Android ---------
✅  sdkmanager: Loading package information...                                                  Loading local repository...                                                     [=========                              ] 25% Loading local repository...       [=========                              ] 25% Fetch remote repository...        [=======================================] 100% Fetch remote repository...
Installed packages:
  Path                 | Version | Description                    | Location
  -------              | ------- | -------                        | -------
  build-tools;33.0.2   | 33.0.2  | Android SDK Build-Tools 33.0.2 | build-tools/33.0.2
  build-tools;34.0.0   | 34.0.0  | Android SDK Build-Tools 34     | build-tools/34.0.0
  build-tools;35.0.0   | 35.0.0  | Android SDK Build-Tools 35     | build-tools/35.0.0
  platform-tools       | 36.0.2  | Android SDK Platform-Tools     | platform-tools
  platforms;android-34 | 3       | Android SDK Platform 34        | platforms/android-34
  platforms;android-35 | 2       | Android SDK Platform 35        | platforms/android-35

--------- Flutter ---------
✅  flutter: Flutter 3.41.2 • channel stable • https://github.com/flutter/flutter.git
Framework • revision 90673a4eef (8 months ago) • 2026-02-18 13:54:59 -0800
Engine • hash d96704abcce17ff165bbef9d77123407ef961017 (revision 6c0baaebf7) (7 months ago) • 2026-02-18 19:22:23.000Z
Tools • Dart 3.11.0 • DevTools 2.54.1

--------- PHP ---------
✅  php: PHP 8.3.6 (cli) (built: Jan  7 2026 08:40:32) (NTS)
Copyright (c) The PHP Group
Zend Engine v4.3.6, Copyright (c) Zend Technologies
    with Zend OPcache v8.3.6, Copyright (c), by Zend Technologies
✅  composer: PHP version 8.3.6 (/usr/bin/php8.3)
Run the "diagnose" command to get more detailed diagnostics output.
Composer version 2.9.5 2026-01-29 11:40:53

--------- Ruby ---------
✅  ruby: ruby 3.2.3 (2024-01-18 revision 52bb2ac0a6) [x86_64-linux-gnu]
✅  gem: 3.4.20
✅  bundle: 4.0.7

--------- .NET ---------
✅  dotnet: 8.0.124 [/usr/lib/dotnet/sdk]
10.0.103 [/usr/lib/dotnet/sdk]

--------- Docker ---------
✅  docker: Docker version 29.2.1, build a5c7197
✅  docker: Docker Compose version v5.1.0

--------- PlayWright ---------
✅  playwright: Version 1.58.0

--------- Other Utilities ---------
✅  awk: GNU Awk 5.2.1, API 3.2, PMA Avon 8-g1, (GNU MPFR 4.2.1, GNU MP 6.3.0)
Copyright (C) 1989, 1991-2022 Free Software Foundation.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
✅  curl: curl 8.5.0 (x86_64-pc-linux-gnu) libcurl/8.5.0 OpenSSL/3.0.13 zlib/1.3 brotli/1.1.0 zstd/1.5.5 libidn2/2.3.7 libpsl/0.21.2 (+libidn2/2.3.7) libssh/0.10.6/openssl/zlib nghttp2/1.59.0 librtmp/2.3 OpenLDAP/2.6.10
Release-Date: 2023-12-06, security patched: 8.5.0-2ubuntu10.7
Protocols: dict file ftp ftps gopher gophers http https imap imaps ldap ldaps mqtt pop3 pop3s rtmp rtsp scp sftp smb smbs smtp smtps telnet tftp
Features: alt-svc AsynchDNS brotli GSS-API HSTS HTTP2 HTTPS-proxy IDN IPv6 Kerberos Largefile libz NTLM PSL SPNEGO SSL threadsafe TLS-SRP UnixSockets zstd
✅  git: git version 2.53.0
✅  grep: grep (GNU grep) 3.11
Copyright (C) 2023 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by Mike Haertel and others; see
<https://git.savannah.gnu.org/cgit/grep.git/tree/AUTHORS>.

grep -P uses PCRE2 10.42 2022-12-11
✅  gzip: gzip 1.12
Copyright (C) 2018 Free Software Foundation, Inc.
Copyright (C) 1993 Jean-loup Gailly.
This is free software.  You may redistribute copies of it under the terms of
the GNU General Public License <https://www.gnu.org/licenses/gpl.html>.
There is NO WARRANTY, to the extent permitted by law.

Written by Jean-loup Gailly.
✅  jq: jq-1.7
✅  make: GNU Make 4.3
Built for x86_64-pc-linux-gnu
Copyright (C) 1988-2020 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
✅  rg: ripgrep 14.1.0

features:-simd-accel,+pcre2
simd(compile):+SSE2,-SSSE3,-AVX2
simd(runtime):+SSE2,+SSSE3,+AVX2

PCRE2 10.42 is available (JIT is available)
✅  sed: sed (GNU sed) 4.9
Packaged by Debian
Copyright (C) 2022 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by Jay Fenlason, Tom Lord, Ken Pizzini,
Paolo Bonzini, Jim Meyering, and Assaf Gordon.

✅  tar: tar (GNU tar) 1.35
Copyright (C) 2023 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by John Gilmore and Jay Fenlason.
✅  tmux: tmux 3.4
✅  yq: yq 0.0.0

-------------------------------------
Environment check complete.
```

## 2. Package mirror provenance
```bash
$ cat /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$'
deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu       noble stable
Types: deb
URIs: https://ppa.launchpadcontent.net/git-core/ppa/ubuntu/
Suites: noble
Components: main
Signed-By:
 -----BEGIN PGP PUBLIC KEY BLOCK-----
 .
 mQINBGYo2OYBEADVRjI+o29u9izslaVr0Xqj8hpmo/2su/Iey1PgoS6A3hMxR4R4
 eZ3u9dRh/gRHXNjxqRMfKj88G6ciqa/7ty8Vfc1eKl3z7yjL1pWOEzcGLKaSB8qd
 MmsxCw31nFNEbzlymgK0+KPubQ5OrIzeSikpfDVGT4HLgO42ppGY+cVy2/bbNv6O
 mmPXcw8gkxRCWFiGAO5jJYG1SyGbhr9Krbf6o+LDUJeDYPTQRMf702IYZ8Bp00ix
 HyK2YOUNM14rr7092o2dw9GKxnJszF4cET+LxRddrREuB3sBlAZav/I0hZtQsKZ3
 QTvpStf2MwIy8Ymj94+BsZaktP0d36wigGn8RWJHrhSVyjujS8YxWRWdjrLUI1ra
 42pyIYZi39IXtsTM71rihQVrsEHbMQ7a5HGRK6eYyHVPrtsXXykNqhVPekLNiFWm
 IekoSH1EwMsQv8y+k3nkCwTCkTHJaueB7awee0Zs5QBwbCm+qPyqCXoVDLEwdQOr
 CHKAfNADtsFQsk/yiTC/+Lmtur/okp38VpJWXg8DphHFjd1KwqQ5E9qZi+tXs/JD
 UXd93VBUdoGGaHK9fj/URxUBOVopGaOXGVYtGFWPn9q8MaNcrESZ48sXDfsVgUVD
 RJ4puKLHjIUtDlCnMQO6lekIhEo4sxtbDnwIUmQp7B9l+U99u+uzBI96cQARAQAB
 tChMYXVuY2hwYWQgUFBBIGZvciBVYnVudHUgR2l0IE1haW50YWluZXJziQJOBBMB
 CgA4FiEE+RGrGEMXYwxZlwlz42PJD48bYhcFAmYo2OYCGwMFCwkIBwIGFQoJCAsC
 BBYCAwECHgECF4AACgkQ42PJD48bYhdwUQ//UFR3i/6zpizJMTA9mpz7hGC9IJV8
 UDoWoaVgl+OR1Ldfz+jvr3K55LZyIMU1o6bbLqbEnoWa2VpRv2za/SCbPqo1igio
 p97EJ2irGytFOhCDd+o3s0djfsXpA7jygAK6COnMx3ejnPhaBA194HbYDhp7KA5b
 gZcqvYeRN1qk9QL99voFYeUWAPnqkLLrNuAcq9qTotmyYZQI61rdAH8P4odgMtU7
 UiS4yLirkAiNCqT+TK07EXvaWSXcqZhgt1HmP+BZhrx/vLT4FlH52CCjamQWeFA2
 mLKX/RSx/JTux1UDroX6L9JdUyMzOrLk22Zz9Tb3FK2ysHy72jRKmUv87ctIMcgD
 u8BY3Mfe/Rw8vPMuBEaAsVfvWl7uYSt81dzjkxtt6ZvIFF5PBR2IhFJVosDbpSnk
 g9/b22Ipjta3ULW8oOaNZjdcRNQ5StpApzZIUoZoP83ZWafwQoSrW7Rz3KvwYAdL
 d3OAfuiW9i7YdLCkvaujBt6KA4tn56fcsp14FzLZrgcj+7XUpW4/yEJFHCCu5f2l
 NWvN37suUTfzbMLZVS6rC1s3qrjOD+C3dvL/dCUlcTfrrsTcs/UnaVXFq0V6NLhA
 ZZxOIVUedn7nGKbaecwTt6taIjpxj0jCBxWy6RcysIkv2xluRcl2UY+HapB8x1Dx
 8giHUSvkXHr4c7I=
 =yxbG
 -----END PGP PUBLIC KEY BLOCK-----
deb [arch=amd64] https://dl.google.com/linux/chrome/deb/ stable main
Types: deb
URIs: http://us-central1.gce.archive.ubuntu.com/ubuntu/
Suites: noble noble-updates noble-backports
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
Types: deb
URIs: http://us-central1.gce.archive.ubuntu.com/ubuntu/
Suites: noble-security
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
```

## 3. Storage I/O throughput
### Upperdir write benchmark
```bash
$ dd if=/dev/zero of=/app/io_bench.tmp bs=1M count=256 conv=fdatasync 2>&1 && rm -f /app/io_bench.tmp
256+0 records in
256+0 records out
268435456 bytes (268 MB, 256 MiB) copied, 2.39108 s, 112 MB/s
```

### Base image read benchmark
```bash
$ dd if=/dev/vda of=/dev/null bs=1M count=256 2>&1
dd: failed to open '/dev/vda': Permission denied
```

## 4. Headless Chrome automation
### Versions
```bash
$ google-chrome --version
Google Chrome 145.0.7632.116
$ /opt/jules/playwright/bin/playwright --version
Version 1.58.0
```

### Headless DOM fetch test
```bash
$ google-chrome --headless --disable-gpu --dump-dom https://example.com 2>/dev/null | head -n 15
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><link rel="icon" href="data:,"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Example Domain</title><style>html{color-scheme:light dark;background:light-dark(#eee,#222)}body{font:16px/1.6 system-ui,sans-serif;max-width:26em;margin:auto;padding:25vh 2em 2em;text-align:center}</style></head><body><style>svg{display:block;margin:-2.75em auto 0;opacity:.55}p+p{font-size:.875em;opacity:.6}</style><svg viewBox="0,0,20,20" width="44" height="44" fill="currentColor" aria-hidden="true"><path fill="none" stroke="currentColor" stroke-width="1.3" stroke-linejoin="round" d="M6 4H3v12q4 0 7 1.5-1-3.5-4-4.5V2q3.5 1 4 3v12.5q3-1.5 7-1.5V4q-4.5 0-7 1"></path><g transform="rotate(-6,13.6,8.3)"><path id="q" d="M11.5 6.6h1.8v1.8l-1 1.6-.6-.3.8-1.3h-1z"></path><use href="#q" x="2.4"></use></g></svg><p lang="en">This domain is for use in documentation examples without needing permission. This is not a service; avoid relying on it for testing and monitoring purposes.</p><p lang="ar" dir="rtl">هذا النطاق مُخصص للاستخدام في أمثلة التوثيق دون الحاجة إلى إذن. هذه ليست خدمة، يُرجى تجنب الاعتماد عليها لأغراض الاختبار والمراقبة.</p><p lang="zh">该域名仅用于文档示例，无需获得许可。这并非一项服务，请勿将其用于测试和监控目的。</p><p lang="fr">L’usage de ce domaine est réservé à des exemples de documentation, sans autorisation préalable.  Il ne s’agit pas d’un service ; son utilisation à des fins de test ou de surveillance est à éviter.</p><p lang="ru">Данный домен предназначен для использования в примерах документации без необходимости получения предварительного разрешения. Это не сервис; не рекомендуется его использование для тестирования и мониторинга.</p><p lang="es">Este dominio está destinado al uso en ejemplos de documentación sin necesidad de permiso. Esto no es un servicio; evitar utilizarlo para realizar pruebas o monitoreos.</p><a href="https://iana.org/help/example-domains">Learn more</a><script src="/s.js"></script>
</body></html>
```

## 5. Container tooling & VFS driver test
### Tooling check
```bash
$ which podman runc fuse-overlayfs 2>&1
/usr/bin/runc
$ cat /etc/docker/daemon.json 2>/dev/null || echo "no daemon.json"
no daemon.json
```

### Ad-hoc VFS execution test
```bash
$ sudo dockerd --storage-driver=vfs -H unix:///tmp/vfs.sock --data-root /tmp/vfs-data --pidfile /tmp/vfs.pid >/dev/null 2>&1 & sleep 3; docker -H unix:///tmp/vfs.sock run --rm alpine uname -a 2>&1; sudo kill $(cat /tmp/vfs.pid 2>/dev/null) 2>/dev/null || true; sudo rm -rf /tmp/vfs-data /tmp/vfs.* 2>/dev/null || true
Unable to find image 'alpine:latest' locally
latest: Pulling from library/alpine
e2de96513ba9: Pulling fs layer
e2de96513ba9: Verifying Checksum
e2de96513ba9: Download complete
e2de96513ba9: Pull complete
Digest: sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6
Status: Downloaded newer image for alpine:latest
Linux 1aa3a379c401 6.8.0 #1 SMP PREEMPT_DYNAMIC Fri Feb 20 20:38:43 UTC 2026 x86_64 Linux
```
