# Uptime and Storage Probe

## 1. Uptime
```bash
$ uptime -s
2026-10-05 19:58:01
```

## 2. /dev/vdb Storage Probe
```bash
$ sudo tune2fs -l /dev/vdb
tune2fs 1.47.0 (5-Feb-2023)
Filesystem volume name:   overlay
Last mounted on:          /
Filesystem UUID:          a9893320-d2ab-4aca-98ea-9a5954d46d7d
Filesystem magic number:  0xEF53
Filesystem revision #:    1 (dynamic)
Filesystem features:      has_journal ext_attr resize_inode dir_index filetype needs_recovery extent 64bit flex_bg sparse_super large_file huge_file dir_nlink extra_isize metadata_csum
Filesystem flags:         signed_directory_hash
Default mount options:    user_xattr acl
Filesystem state:         clean
Errors behavior:          Continue
Filesystem OS type:       Linux
Inode count:              6553600
Block count:              26214400
Reserved block count:     1310720
Overhead clusters:        557842
Free blocks:              25652380
Free inodes:              6553533
First block:              0
Block size:               4096
Fragment size:            4096
Group descriptor size:    64
Reserved GDT blocks:      1024
Blocks per group:         32768
Fragments per group:      32768
Inodes per group:         8192
Inode blocks per group:   512
Flex block group size:    16
Filesystem created:       Fri Mar  6 17:10:25 2026
Last mount time:          Fri Mar  6 17:10:28 2026
Last write time:          Mon Oct  5 19:38:46 2026
Mount count:              1
Maximum mount count:      -1
Last checked:             Fri Mar  6 17:10:25 2026
Check interval:           0 (<none>)
Lifetime writes:          123 MB
Reserved blocks uid:      0 (user root)
Reserved blocks gid:      0 (group root)
First inode:              11
Inode size:	          256
Required extra isize:     32
Desired extra isize:      32
Journal inode:            8
Default directory hash:   half_md4
Directory Hash Seed:      7f51f0ee-e9a1-4b39-adde-4b88ec91ba04
Journal backup:           inode blocks
Checksum type:            crc32c
Checksum:                 0x9249368b
```
