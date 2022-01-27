/*
 * CS252: Shell project
 *
 * Template file.
 * You will need to add more code here to execute the command table.
 *
 * NOTE: You are responsible for fixing any bugs this code may have!
 *
 * DO NOT PUT THIS PROJECT IN A PUBLIC REPOSITORY LIKE GIT. IF YOU WANT 
 * TO MAKE IT PUBLICALLY AVAILABLE YOU NEED TO REMOVE ANY SKELETON CODE 
 * AND REWRITE YOUR PROJECT SO IT IMPLEMENTS FUNCTIONALITY DIFFERENT THAN
 * WHAT IS SPECIFIED IN THE HANDOUT. WE OFTEN REUSE PART OF THE PROJECTS FROM  
 * SEMESTER TO SEMESTER AND PUTTING YOUR CODE IN A PUBLIC REPOSITORY
 * MAY FACILITATE ACADEMIC DISHONESTY.
 */

#include <cstdio>
#include <cstdlib>
#include <unistd.h>
#include <iostream>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <fstream>
#include <sys/wait.h>
#include <string.h>
#include <signal.h>
#include "command.hh"
#include "shell.hh"

std::vector<int> _backgndPID;

extern void myunputc(int);

std::vector<std::string> _sourceCommands;

int totCommands = 0;

int lastReturnCode = 0;

int lastBackPID = -1;

std::string lastUsedArg("");

Command::Command() {
    // Initialize a new vector of Simple Commands
    _simpleCommandsArray = std::vector<SimpleCommand *>();

    _outFileName = NULL;
    _inFileName = NULL;
    _errFileName = NULL;
    _backgnd = false;
    _append_out = false;
    _append_err = false;
    _outRedirect = 0;
}

void Command::insertSimpleCommand( SimpleCommand * simpleCommand ) {
    // add the simple command to the vector
    _simpleCommandsArray.push_back(simpleCommand);
}

void Command::clear() {
    // deallocate all the simple commands in the command vector
    for (auto simpleCommand : _simpleCommandsArray) {
        delete simpleCommand;
    }

    // remove all references to the simple commands we've deallocated
    // (basically just sets the size to 0)
    _simpleCommandsArray.clear();


    if ( _outFileName ) {
        if ( _errFileName ) {
          if ( _outFileName == _errFileName ) {
            _errFileName = NULL;
          }
        }
        delete _outFileName;
    }
    _outFileName = NULL;

    if ( _inFileName ) {
        delete _inFileName;
    }
    _inFileName = NULL;

    if ( _errFileName ) {
        delete _errFileName;
    }
    _errFileName = NULL;
    _append_err = false;
    _append_out = false;
    _backgnd = false;
    _outRedirect = 0;
}

void Command::print() {
    printf("\n\n");
    printf("              COMMAND TABLE                \n");
    printf("\n");
    printf("  #   Simple Commands\n");
    printf("  --- ----------------------------------------------------------\n");

    int i = 0;
    // iterate over the simple commands and print them nicely
    for ( auto & simpleCommand : _simpleCommandsArray ) {
        printf("  %-3d ", i++ );
        simpleCommand->print();
    }

    printf( "\n\n" );
    printf( "  Output       Input        Error        Background\n" );
    printf( "  ------------ ------------ ------------ ------------\n" );
    printf( "  %-12s %-12s %-12s %-12s\n",
            _outFileName?_outFileName->c_str():"default",
            _inFileName?_inFileName->c_str():"default",
            _errFileName?_errFileName->c_str():"default",
            _backgnd?"YES":"NO");
    printf( "\n\n" );
}

extern "C" void child_terminator(int sig) {
  int pid = waitpid(-1, NULL, 0);
  for ( unsigned int i = 0; i < _backgndPID.size(); i++ ) {
    if ( pid == _backgndPID[i] ) {
      _backgndPID.erase(_backgndPID.begin() + i);
      printf("%d\n", pid);
    }
  }
}

void Command::execute() {
    // Don't do anything if there are no simple commands
    if ( _simpleCommandsArray.size() == 0 ) {
      if ( totCommands == 0 ) {
        Shell::prompt();
        return;
      }
    }
    // Don't do anything if output redirection is ambiguous
    if ( _outRedirect > 1 ) {
      fprintf(stderr, "Ambiguous output redirect.\n");
      if ( totCommands == 0 ) {
        Shell::prompt();
        return;
      }
    }
    // Print contents of Command data structure
    //print(); 

    // Below is signal setup for handling zombies
    struct sigaction sa;
    sa.sa_handler = child_terminator;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESTART;

    if ( sigaction(SIGCHLD, &sa, NULL )) {
      fprintf(stderr, "sigaction");
      _exit(2);
    }

    // Add execution here
    int tempin = dup(0);
    int tempout = dup(1);
    int temperr = dup(2);
    int fdin = -1;
    int fderr = -1;
    int fdout = -1;
    //Error file redirection
    if ( _errFileName != NULL ) {
      char *errFileName = new char[_errFileName->length() + 1];
      strcpy(errFileName, _errFileName->c_str());
      if ( _append_err ) {
        fderr = open(errFileName, O_WRONLY|O_CREAT|O_APPEND, 0660);
        if ( fderr < 0 ) {
          fprintf(stderr, "errfile");
          exit(0);
        }
      }
      else {
        fderr = open(errFileName, O_RDWR|O_CREAT|O_TRUNC, 0660);
        if ( fderr < 0 ) {
          fprintf(stderr, "errfile");
          exit(0);
        }
      }
    }
    else {
      fderr = dup(temperr);
    }
    dup2(fderr, 2);
    close(fderr);
    //Initital input file redirection
    if ( _inFileName != NULL ) {
      char *inFileName = new char[_inFileName->length() + 1];
      strcpy(inFileName, _inFileName->c_str());
      fdin = open(inFileName, O_RDONLY);
      if ( fdin < 0 ) {
        fprintf(stderr, "infile");
        exit(0);
      }
    }
    else {
      fdin = dup(tempin);
    }

    int ret = -1;
    for ( unsigned int i = 0; i < _simpleCommandsArray.size(); i++ ) {
      //Exit if the command is "exit" exactly
      if ( i == 0 ) {
        if ( strcmp(_simpleCommandsArray[i]->_argumentsArray[0]->c_str(), "exit") == 0 ) {
          fprintf(stdout, "\nGoodbye!!\n\n");
          _exit(0);
        }
      }
      if ( strcmp(_simpleCommandsArray[i]->_argumentsArray[0]->c_str(), "unsetenv") == 0 ) {
        if ( _simpleCommandsArray[i]->_argumentsArray.size() == 2 ) {
          unsetenv(_simpleCommandsArray[i]->_argumentsArray[1]->c_str());
        }
        else {
          fprintf(stdout, "syntax error\n");
        }
        continue;
      }
      if ( strcmp(_simpleCommandsArray[i]->_argumentsArray[0]->c_str(), "setenv") == 0 ) {
        if ( _simpleCommandsArray[i]->_argumentsArray.size() == 3 ) {
          setenv(_simpleCommandsArray[i]->_argumentsArray[1]->c_str(), _simpleCommandsArray[i]->_argumentsArray[2]->c_str(), 1);
        }
        else {
          fprintf(stdout, "syntax error\n");
        }
        continue;
      }
      if ( strcmp(_simpleCommandsArray[i]->_argumentsArray[0]->c_str(), "cd") == 0 ) {
        if ( _simpleCommandsArray[i]->_argumentsArray.size() == 1 ) {
          chdir(getenv("HOME"));
        }
        else {
          int suc_change = chdir(_simpleCommandsArray[i]->_argumentsArray[1]->c_str());
          if ( suc_change == -1 ) {
            fprintf(stderr, "cd: can't cd to %s\n", _simpleCommandsArray[i]->_argumentsArray[1]->c_str());
          }
        }
        continue;
      }
      if ( strcmp(_simpleCommandsArray[i]->_argumentsArray[0]->c_str(), "source") == 0 ) {
        if ( _simpleCommandsArray[i]->_argumentsArray.size() == 2 ) {
          std::ifstream sourceFile(_simpleCommandsArray[i]->_argumentsArray[1]->c_str());
          std::string str;
          while (std::getline(sourceFile, str)) {
            _sourceCommands.push_back(str.append("\n"));
          }
        }
        else {
          fprintf(stdout, "syntax error\n");
        }
        totCommands = _sourceCommands.size();
        continue;
      }
      dup2(fdin, 0);
      close(fdin);
      //If we are on the last command, redirect output to outfile (if specified)
      if ( i == _simpleCommandsArray.size() - 1 ) {
        lastUsedArg = *(_simpleCommandsArray[i]->_argumentsArray[_simpleCommandsArray[i]->_argumentsArray.size() - 1]);
        if ( _outFileName != NULL ) {
          char *outFileName = new char[_outFileName->length() + 1];
          strcpy(outFileName, _outFileName->c_str());
          if ( _append_out ) {
            fdout = open(outFileName, O_WRONLY|O_CREAT|O_APPEND, 0660);
            if ( fdout < 0 ) {
              fprintf(stderr, "outfile");
              exit(0);
            }
          }
          else {
            fdout = open(outFileName, O_WRONLY|O_CREAT|O_TRUNC, 0660);
            if ( fdout < 0 ) {
              fprintf(stderr, "outfile");
              exit(0);
            }
          }
        }
        else {
          fdout = dup(tempout);
        }
      }
      //If we aren't on the last command, redirect output to input of next
      else {
        int * fdpipe = new int[2];
        pipe(fdpipe);
        fdout = fdpipe[1];
        fdin = fdpipe[0];
      }
      dup2(fdout, 1);
      close(fdout);
      ret = fork();
      if ( ret == 0 ) {
        //Turn the c++ strings into c strings so we can use them with execvp
        if ( strcmp(_simpleCommandsArray[i]->_argumentsArray[0]->c_str(), "printenv") == 0 ) {
          char *cur_environ = environ[0];
          int cur_eni = 1;
          while ( cur_environ != NULL ) {
            fprintf(stdout, "%s\n", cur_environ);
            cur_environ = environ[cur_eni];
            cur_eni++;
          }
          exit(0);
        }
        char ** cur_command = new char* [_simpleCommandsArray[i]->_argumentsArray.size() + 1]; 
        int word_num = 0;
        for ( auto arg : _simpleCommandsArray[i]->_argumentsArray ) {
          char * c_string = new char [arg->length() + 1];
          strcpy (c_string, arg->c_str());
          cur_command[word_num] = strdup(c_string);
          word_num++;
        }
        cur_command[_simpleCommandsArray[i]->_argumentsArray.size()] = NULL; 
        execvp(cur_command[0], cur_command);
        fprintf(stderr, "execvp");
        _exit(1);
      }
      else if ( ret < 0 ) {
        fprintf(stderr, "fork");
        exit(0);
      }
    }
    if ( !_backgnd ) {
      int status = 0;
      waitpid(ret, &status, 0);
      if ( WIFEXITED(status) ) {
        lastReturnCode = WEXITSTATUS(status);
      }
      if ( lastReturnCode != 0 ) {
        if ( getenv("ON_ERROR") != NULL ) {
          fprintf(stderr, "%s\n", getenv("ON_ERROR"));
        }
      }
    }
    else {
      _backgndPID.push_back(ret);
      lastBackPID = ret;
    }
    dup2(tempin, 0);
    close(tempin);
    dup2(tempout, 1);
    close(tempout);
    dup2(temperr, 2);
    close(temperr);

    // Clear to prepare for next command
    clear();
    // Print new prompt
    if ( totCommands == 0 ) {
      Shell::prompt();
    }

    if ( totCommands != 0 ) {
      std::string curstr(_sourceCommands[0]);
      for ( int i = curstr.size() - 1; i >= 0; i-- ) {
        myunputc(curstr.at(i));
      }
      _sourceCommands.erase(_sourceCommands.begin() + 0);
      totCommands--;
    }

}

SimpleCommand * Command::_currSimpleCommand;
