# PAM and Auth Security Configuration

## 1. Sudoers Configuration (`/etc/sudoers.d/`)

Listing `/etc/sudoers.d/`:

```text
README
jules
swebot
```

Content of `/etc/sudoers.d/jules`:

```text
jules ALL=(ALL) NOPASSWD: ALL
```

Content of `/etc/sudoers.d/swebot`:

```text
swebot ALL=(ALL) NOPASSWD: ALL
```

Both default non-root identities (`jules` and `swebot`) have unrestricted, passwordless sudo access (`NOPASSWD: ALL`).

## 2. PAM Configuration Customizations

`diff /etc/pam.d/common-auth /etc/pam.d/sshd`:
Standard Ubuntu PAM stack where SSHD includes `common-auth`, `common-account`, `common-session`, and `common-password`, plus `pam_nologin.so`, `pam_selinux.so`, `pam_loginuid.so`, `pam_keyinit.so`, `pam_motd.so`, `pam_mail.so`, and `pam_limits.so`.

## 3. SSH Authorized Keys (Fingerprints & Key Types Only)

Authorized key fingerprints (`ssh-keygen -lf`):

- `/root/.ssh/authorized_keys`: `4096 SHA256:+76aRhvNghBah8rUnsutpDfo+xt9BatCwzBu2auwy5I root@localhost (RSA)`
- `/home/jules/.ssh/authorized_keys`: `4096 SHA256:+76aRhvNghBah8rUnsutpDfo+xt9BatCwzBu2auwy5I root@localhost (RSA)`

Note: Root and Jules share the exact same authorized SSH key identity.

## 4. Host Identity Keys & Fingerprints

SSH Host Key Fingerprints (`/etc/ssh/ssh_host_*_key.pub`):

```text
256 SHA256:AZkAkLsepSzo2aEzPB7o6K01vXc2g9eUY+VgVD6nhEQ root@buildkitsandbox (ECDSA)
256 SHA256:VAASjHFfmYJjVxjaYl+joruBH144dcqx4+Mqe3FDZXQ root@buildkitsandbox (ED25519)
3072 SHA256:Ok2G/vxCnpxEPk9ljNsVmGJASIzbc7bkRFPp6+y7pOk root@buildkitsandbox (RSA)
```
