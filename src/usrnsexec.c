#define _GNU_SOURCE
#include <sched.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <fcntl.h>


struct subargs {
  char** args;
  int count;
};

int forkexec(char* argv[]){
  int pid = fork();
  if(!pid){
    execvp(argv[0], argv);
    exit(127);
  }
  int status = -1;
  while( waitpid(pid, &status, 0) == -1 && errno == EINTR );
  return WEXITSTATUS(status);
}

int main(int argc, char* argv[]){
  struct subargs subargs[3];
  memset(subargs,0,sizeof(subargs));
  subargs[0].args = argv + 1;
  int j=0;
  for(int i=1; i<argc-1; i++){
    if(strcmp(argv[i],"--")){
      subargs[j].count++;
      continue;
    }
    argv[i] = 0;
    j += 1;
    subargs[j].args = argv + i + 1;
    if(j >= 2){
      subargs[j].count = argc - i - 1;
      j += 1;
      break;
    }
  }

  if(j != 3 || subargs[0].count % 3 || subargs[1].count % 3 || !subargs[2].count){
    printf("Usage: %s [uid lower count...] -- [gid lower count...] -- cmd [args...]\n", argv[0]);
    return 1;
  }

  char pid[256] = {0};
  snprintf(pid, sizeof(pid), "%d", getpid());

  int pfds[2];
  if(pipe(pfds) == -1){
    perror("pipe failed");
    exit(1);
  }

  int fpid = fork();
  if(fpid < 0){
    perror("fork failed");
    exit(1);
  }else if(!fpid){

    close(pfds[1]);

    while(1){
      int p = -1;
      int ret = read(pfds[0], &p, sizeof(p));
      if(ret == 0) break;
      if(ret == -1 && errno == EINTR)
        continue;
      exit(ret);
    }

    {
      int argcount = subargs[0].count;
      char* cmd[argcount+3];
      cmd[0] = "newuidmap";
      cmd[1] = pid;
      memcpy(cmd+2, subargs[0].args, argcount * sizeof(char*));
      cmd[argcount+2] = 0;
      int res = forkexec(cmd);
      if(res){
        fprintf(stderr, "newuidmap failed: %d\n", res);
        exit(res);
      }
    }

    {
      int argcount = subargs[1].count;
      char* cmd[argcount+3];
      cmd[0] = "newgidmap";
      cmd[1] = pid;
      memcpy(cmd+2, subargs[1].args, argcount * sizeof(char*));
      cmd[argcount+2] = 0;
      int res = forkexec(cmd);
      if(res){
        fprintf(stderr, "newgidmap failed: %d\n", res);
        exit(res);
      }
    }

    return 0;
  }else{

    close(pfds[0]);

    unshare(CLONE_NEWUSER);
    {
      int fd = open("/proc/self/setgroups",O_WRONLY);
      if(!fd){
        perror("Failed to open /proc/self/setgroups");
        write(pfds[1],(int[]){1},sizeof(int));
        close(pfds[1]);
        exit(1);
      }
      write(fd,"deny",4);
      close(fd);
    }

    close(pfds[1]);

    int status = -1;
    while( waitpid(fpid, &status, 0) == -1 && errno == EINTR );
    status = WEXITSTATUS(status);

    if(status)
      exit(status);

    execvp(subargs[2].args[0],subargs[2].args);
    return errno;
  }
}

