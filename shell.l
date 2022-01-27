
/*
 *
 * CS-252 
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 * NOTICE: This lab is property of Purdue University. You should not for any reason make this code public.
 */

%{

#include <cstring>
#include <string.h>
#include <unistd.h>
#include <limits.h>
#include <stdlib.h>
#include <sys/types.h>
#include "y.tab.hh"

extern "C" char * read_line();

static  void yyunput (int c,char *buf_ptr  );

extern int lastReturnCode;

extern int lastBackPID;

extern std::string lastUsedArg;

extern std::string relPath;

void myunputc(int c) {
  unput(c);
}

int mygetc(FILE *f) {
  static char *p;
  char ch;

  if ( !isatty(0) ) {
    return getc(f);
  }

  if ( p == NULL || *p == 0 ) {
    char * s = read_line();
    p = s;
  }

  ch = *p;
  p++;

  return ch;
}

#undef getc
#define getc(f) mygetc(f)

%}

%option noyywrap

%%

\n {
  return NEWLINE;
}

[ \t] {
  /* Discard spaces and tabs */
}

">" {
  return GREAT;
}

">>" {
  return GREATGREAT;
}

"|" {
  return PIPE;
}

"&" {
  return AMPERSAND;
}

"2>" {
  return TWOGREAT;
}

"<" {
  return LESS;
}

">&" {
  return GREATAMPERSAND;
}

">>&" {
  return GREATGREATAMPERSAND;
}

\`[^\`\n]*\` {
  /* If there is a subshell call, this essentially takes that call and executes it inside of another shell */
  std::string subcommand(yytext);
  subcommand.erase(subcommand.begin() + 0);
  subcommand.erase(subcommand.begin() + subcommand.size() - 1);
  subcommand.append("\nexit\n");
  int tempin = dup(0);
  int tempout = dup(1);
  int * pin = new int[2];
  int * pout = new int[2];
  pipe(pin);
  pipe(pout);
  write(pin[1], subcommand.c_str(), subcommand.size());
  close(pin[1]);
  dup2(pin[0], 0);
  dup2(pout[1], 1);
  close(pout[1]);
  close(pin[0]);
  int ret = fork();
  if ( ret < 0 ) {
    fprintf(stderr, "fork subshell");
    exit(0);
  }
  else if ( ret == 0 ) {
    execvp("/proc/self/exe", NULL);
    fprintf(stderr, "execvp subshell");
    _exit(0);
  }
  dup2(tempin, 0);
  dup2(tempout, 1);
  close(tempin);
  close(tempout);
  std::string buffer("");
  char cur_char;
  while ( read(pout[0], &cur_char, 1) != 0 ) {
    if ( cur_char == '\n' ) {
      cur_char = ' ';
    }
    else if ( cur_char == '>' ) {
      buffer.append("\\>");
      continue;
    }
    else if ( cur_char == '<' ) {
      buffer.append("\\<");
      continue;
    }
    else if ( cur_char == '|' ) {
      buffer.append("\\|");
      continue;
    }
    else if ( cur_char == '&' ) {
      buffer.append("\\&");
      continue;
    }
    else if ( cur_char == '\\' ) {
      buffer.append("\\");
      continue;
    }
    else if ( cur_char == '\"' ) {
      buffer.append("\\\"");
      continue;
    }
    else if ( cur_char == '$' ) {
      buffer.append("\\$");
      continue;
    }
    else if ( cur_char == '`' ) {
      buffer.append("\\`");
      continue;
    }
    buffer.push_back(cur_char);
  }
  close(pout[0]);
  for ( int i = buffer.size() - 1; i >= 0; i-- ) {
    myunputc(buffer.at(i));
  }
}

[$][(][^\n]+[)] {
  /* This is also subshell */
  std::string subcommand(yytext);
  subcommand.erase(subcommand.begin() + 0);
  subcommand.erase(subcommand.begin() + 0);
  subcommand.erase(subcommand.begin() + subcommand.size() - 1);
  subcommand.append("\nexit\n");
  int tempin = dup(0);
  int tempout = dup(1);
  int * pin = new int[2];
  int * pout = new int[2];
  pipe(pin);
  pipe(pout);
  write(pin[1], subcommand.c_str(), subcommand.size());
  close(pin[1]);
  dup2(pin[0], 0);
  dup2(pout[1], 1);
  close(pout[1]);
  close(pin[0]);
  int ret = fork();
  if ( ret < 0 ) {
    fprintf(stderr, "fork subshell");
    exit(0);
  }
  else if ( ret == 0 ) {
    execvp("/proc/self/exe", NULL);
    fprintf(stderr, "execvp subshell");
    _exit(0);
  }
  dup2(tempin, 0);
  dup2(tempout, 1);
  close(tempin);
  close(tempout);
  std::string buffer("");
  char cur_char;
  while ( read(pout[0], &cur_char, 1) != 0 ) {
    if ( cur_char == '\n' ) {
      cur_char = ' ';
    }
    else if ( cur_char == '>' ) {
      buffer.append("\\>");
      continue;
    }
    else if ( cur_char == '<' ) {
      buffer.append("\\<");
      continue;
    }
    else if ( cur_char == '|' ) {
      buffer.append("\\|");
      continue;
    }
    else if ( cur_char == '&' ) {
      buffer.append("\\&");
      continue;
    }
    else if ( cur_char == '\\' ) {
      buffer.append("\\\\");
      continue;
    }
    else if ( cur_char == '\"' ) {
      buffer.append("\\\"");
      continue;
    }
    else if ( cur_char == '$' ) {
      buffer.append("\\$");
      continue;
    }
    else if ( cur_char == '`' ) {
      buffer.append("\\`");
      continue;
    }
    buffer.push_back(cur_char);
  }
  close(pout[0]);
  for ( int i = buffer.size() - 1; i >= 0; i-- ) {
    myunputc(buffer.at(i));
  }
}

\"[^"\n]*\" {
  std::string cpp_yytext(yytext);
  for ( int i = 0; i < cpp_yytext.size(); i++ ) {
    if ( cpp_yytext.at(i) == '\\' ) {
      cpp_yytext.erase(cpp_yytext.begin() + i);
    }
  }
  yylval.cpp_string = new std::string(cpp_yytext.c_str());
  return PARAWORD;
}

\'[^'\n]*\' {
  std::string cpp_yytext(yytext);
  for ( int i = 0; i < cpp_yytext.size(); i++ ) {
    if ( cpp_yytext.at(i) == '\\' ) {
      cpp_yytext.erase(cpp_yytext.begin() + i);
    }
  }
  yylval.cpp_string = new std::string(cpp_yytext.c_str());
  return PARAWORD;
}

[^ \t\n]+  {
  /* Assume that file names have only alpha chars */
  std::string cpp_yytext(yytext);
  for ( int i = 0; i < cpp_yytext.size(); i++ ) {
    if ( cpp_yytext.at(i) == '\\' ) {
      cpp_yytext.erase(cpp_yytext.begin() + i);
    }
    else if ( cpp_yytext.at(i) == '>' ) {
      if ( i + 1 >= cpp_yytext.size() || cpp_yytext.at(i + 1) != '>' ) {
        for ( int j = cpp_yytext.size() - 1; j >= i; j-- ) {
          if ( j == i ) {
            myunputc(' ');
          }
          myunputc(cpp_yytext.at(j));
        }
        if ( i != 0 ) {
          cpp_yytext = cpp_yytext.substr(0, i);
          break;
        }
        else {
          return NOTHING;
        }
      }
      else {
        if ( i + 2 >= cpp_yytext.size() || cpp_yytext.at(i + 2) != '&' ) {
          for ( int j = cpp_yytext.size() - 1; j >= i; j-- ) {
            if ( j == i + 1 ) {
              myunputc(' ');
            }
            myunputc(cpp_yytext.at(j));
          }
          if ( i != 0 ) {
            cpp_yytext = cpp_yytext.substr(0, i);
            break;
          }
          else {
            return NOTHING;
          }
        }
        else {
          for ( int j = cpp_yytext.size() - 1; j >= i; j-- ) {
            if ( j == i + 2 ) {
              myunputc(' ');
            }
            myunputc(cpp_yytext.at(j));
          }
          if ( i != 0 ) {
            cpp_yytext = cpp_yytext.substr(0, i);
            break;
          }
          else {
            return NOTHING;
          }
        }
      }
    }
    else if ( cpp_yytext.at(i) == '<' ) {
      for ( int j = cpp_yytext.size() - 1; j >= i; j-- ) {
        if ( j == i ) {
          myunputc(' ');
        }
        myunputc(cpp_yytext.at(j));
      }
      if ( i != 0 ) {
        cpp_yytext = cpp_yytext.substr(0, i);
        break;
      }
      else {
        return NOTHING;
      }
    }
    else if ( cpp_yytext.at(i) == '|' ) {
      for ( int j = cpp_yytext.size() - 1; j >= i; j-- ) {
        if ( j == i ) {
          myunputc(' ');
        }
        myunputc(cpp_yytext.at(j));
      }
      if ( i != 0 ) {
        cpp_yytext = cpp_yytext.substr(0, i);
        break;
      }
      else {
        return NOTHING;
      }
    }
    else if ( cpp_yytext.at(i) == '&' ) {
      for ( int j = cpp_yytext.size() - 1; j >= i; j-- ) {
        if ( j == i ) {
          myunputc(' ');
        }
        myunputc(cpp_yytext.at(j));
      }
      cpp_yytext = cpp_yytext.substr(0, i);
      break;
    }
    else if ( cpp_yytext.at(i) == '$' ) {
      if ( i + 1 < cpp_yytext.size() && cpp_yytext.at(i + 1) == '{' ) {
        std::string environ("");
        cpp_yytext.erase(cpp_yytext.begin() + i);
        cpp_yytext.erase(cpp_yytext.begin() + i);
        while ( cpp_yytext.at(i) != '}' ) {
          environ.push_back(cpp_yytext.at(i));
          cpp_yytext.erase(cpp_yytext.begin() + i);
        }
        cpp_yytext.erase(cpp_yytext.begin() + i);
        std::string expanded("");
        if ( environ.compare("_") == 0 ) {
          expanded.append(lastUsedArg);
        } 
        else if ( environ.compare("$") == 0 ) {
          int curPID = getpid();
          expanded.append(std::to_string(curPID));
        }
        else if ( environ.compare("?") == 0 ) {
          expanded.append(std::to_string(lastReturnCode));
        }
        else if ( environ.compare("!") == 0 ) {
          expanded.append(std::to_string(lastBackPID));
        }
        else if ( environ.compare("SHELL") == 0 ) {
          expanded.append(realpath(relPath.c_str(), NULL));
        }
        else if ( getenv(environ.c_str()) != NULL ) {
          expanded.append(getenv(environ.c_str()));
        }
        cpp_yytext.insert(i, expanded);
      }
    }
  }
  yylval.cpp_string = new std::string(cpp_yytext.c_str());
  return WORD;
}
