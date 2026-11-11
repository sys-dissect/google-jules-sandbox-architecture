#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <poll.h>

int main(int argc, char **argv) {
    if (argc < 4) { fprintf(stderr, "usage: %s ip start end\n", argv[0]); return 2; }
    struct sockaddr_in a; memset(&a, 0, sizeof a);
    a.sin_family = AF_INET;
    if (inet_pton(AF_INET, argv[1], &a.sin_addr) != 1) { perror("inet_pton"); return 2; }
    int start = atoi(argv[2]), end = atoi(argv[3]);
    int batch = 1024;
    int *fds = malloc(sizeof(int) * batch);
    struct pollfd *pfd = malloc(sizeof(struct pollfd) * batch);
    int open_count = 0;
    for (int base = start; base <= end; base += batch) {
        int n = 0;
        for (int p = base; p < base + batch && p <= end; p++) {
            int s = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
            if (s < 0) continue;
            a.sin_port = htons((unsigned short)p);
            connect(s, (struct sockaddr *)&a, sizeof a);
            fds[n] = s;
            pfd[n].fd = s; pfd[n].events = POLLOUT; pfd[n].revents = 0;
            n++;
        }
        poll(pfd, n, 250);
        for (int i = 0; i < n; i++) {
            int e = 0; socklen_t l = sizeof e;
            if (pfd[i].revents & (POLLOUT | POLLERR)) {
                getsockopt(fds[i], SOL_SOCKET, SO_ERROR, &e, &l);
                if (e == 0) { printf("%d\n", base + i); open_count++; }
            }
            close(fds[i]);
        }
    }
    fprintf(stderr, "open=%d\n", open_count);
    return 0;
}
