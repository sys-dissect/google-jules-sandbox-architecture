#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/select.h>
#include <linux/vm_sockets.h>
static int one(unsigned cid, unsigned port, unsigned char flags, int sendmsg, const char *msg){
  int s=socket(AF_VSOCK,SOCK_STREAM,0); if(s<0){perror("socket");return -1;}
  struct sockaddr_vm a; memset(&a,0,sizeof a);
  a.svm_family=AF_VSOCK; a.svm_cid=cid; a.svm_port=port; a.svm_flags=flags;
  int fl=fcntl(s,F_GETFL,0); fcntl(s,F_SETFL,fl|O_NONBLOCK);
  int r=connect(s,(struct sockaddr*)&a,sizeof a);
  if(r<0 && errno==EINPROGRESS){
    fd_set w; FD_ZERO(&w); FD_SET(s,&w); struct timeval tv={1,500000};
    r=select(s+1,NULL,&w,NULL,&tv);
    if(r==0){printf("cid=%u port=%u flags=0x%x : TIMEOUT\n",cid,port,flags);close(s);return 0;}
    int e=0; socklen_t l=sizeof e; getsockopt(s,SOL_SOCKET,SO_ERROR,&e,&l);
    if(e){printf("cid=%u port=%u flags=0x%x : ERR %s\n",cid,port,flags,strerror(e));close(s);return -1;}
  } else if(r<0){printf("cid=%u port=%u flags=0x%x : ERR %s\n",cid,port,flags,strerror(errno));close(s);return -1;}
  printf("cid=%u port=%u flags=0x%x : OPEN",cid,port,flags);
  if(sendmsg){
    ssize_t n=send(s,msg,strlen(msg),MSG_NOSIGNAL);
    printf(", sent=%zd",n);
    char buf[256]={0}; struct timeval tv={1,0}; setsockopt(s,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof tv);
    ssize_t m=recv(s,buf,sizeof(buf)-1,0);
    if(m>0){printf(", recv %zd: ",m); for(ssize_t i=0;i<m;i++){if(buf[i]>=32&&buf[i]<127)putchar(buf[i]);else printf("\\x%02x",(unsigned char)buf[i]);}}
    else if(m==0) printf(", peer-closed");
    else printf(", recv=%s",strerror(errno));
  }
  printf("\n"); close(s); return 0;
}
int main(){
  unsigned ports[]={9999,22,1024,53,8080};
  for(unsigned ci=0; ci<sizeof(ports)/sizeof(ports[0]); ci++){
    one(1, ports[ci], VMADDR_FLAG_TO_HOST, 0, NULL);
    one(2, ports[ci], VMADDR_FLAG_TO_HOST, 0, NULL);
    one(1, ports[ci], 0, 0, NULL);
    one(2, ports[ci], 0, 0, NULL);
  }
  printf("--- notify attempt on any opening ---\n");
  one(1,9999,VMADDR_FLAG_TO_HOST,1,"READY=1\nSTATUS=opencode-probe\n");
  one(2,9999,VMADDR_FLAG_TO_HOST,1,"READY=1\nSTATUS=opencode-probe\n");
  one(1,9999,0,1,"READY=1\nSTATUS=opencode-probe\n");
  one(2,9999,0,1,"READY=1\nSTATUS=opencode-probe\n");
  return 0;
}
