#include <cstdio>
#include <unistd.h>
#include <stdlib.h>
#include <signal.h>
#include "shell.hh"

int yyparse(void);

std::string relPath("");

void Shell::prompt() {
  if ( isatty(0) ) {
    if ( getenv("PROMPT") == NULL ) {
      printf("myshell>");
      fflush(stdout);
    }
    else {
      printf("%s", getenv("PROMPT"));
      fflush(stdout);
    }
  }
}

extern "C" void nothing(int sig) {
  printf("\n");
  Shell::prompt();
}

int main(int argc, char* argv[]) {
  struct sigaction sa;
  sa.sa_handler = nothing;
  sigemptyset(&sa.sa_mask);
  sa.sa_flags = SA_RESTART;
  if ( sigaction(SIGINT, &sa, NULL )) {
    fprintf(stderr, "sigaction");
    _exit(2);
  }
  if (argv[0] != NULL) {
    relPath = argv[0];
  }

  Shell::prompt();
  yyparse(); 
}

Command Shell::_currentCommand;
