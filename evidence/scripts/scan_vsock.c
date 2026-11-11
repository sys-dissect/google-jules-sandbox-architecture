#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/socket.h>
#include <poll.h>
#include <linux/vm_sockets.h>

int main(int argc, char **argv) {
    if (argc < 4) { fprintf(stderr, "usage: %s cid start end\n", argv[0]); return 2; }
    unsigned cid = (unsigned)strtoul(argv[1], NULL, 0);
    int start = atoi(argv[2]), end = atoi(argv[3]);
    int batch = 512;
    int *fds = malloc(sizeof(int) * batch);
    struct pollfd *pfd = malloc(sizeof(struct pollfd) * batch);
    int open_count = 0;
    for (int base = start; base <= end; base += batch) {
        int n = 0;
        for (int p = base; p < base + batch && p <= end && p <= 65535; p++) {
            int s = socket(AF_VSOCK, SOCK_STREAM | SOCK_NONBLOCK, 0);
            if (s < 0) continue;
            struct sockaddr_vm a; memset(&a, 0, sizeof a);
            a.svm_family = AF_VSOCK; a.svm_cid = cid; a.svm_port = (unsigned)p;
            connect(s, (struct sockaddr *)&a, sizeof a);
            fds[n] = s;
            pfd[n].fd = s; pfd[n].events = POLLOUT; pfd[n].revents = 0;
            n++;
        }
        poll(pfd, n, 300);
        for (int i = 0; i < n; i++) {
            int e = 0; socklen_t l = sizeof e;
            if (pfd[i].revents & (POLLOUT | POLLERR)) {
                getsockopt(fds[i], SOL_SOCKET, SO_ERROR, &e, &l);
                if (e == 0) { printf("cid=%u port=%d OPEN\n", cid, base + i); open_count++; }
            }
            close(fds[i]);
        }
    }
    fprintf(stderr, "cid=%u open=%d\n", cid, open_count);
    return 0;
}
