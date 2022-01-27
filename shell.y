
/*
 * CS-252
 * shell.y: parser for shell
 *
 * NOTICE: This lab is property of Purdue University. You should not for any reason make this code public.
 */

%code requires 
{
#include <string>

#if __cplusplus > 199711L
#define register      // Deprecated in C++11 so remove the keyword
#endif
}

%union
{
  char        *string_val;
  // Example of using a c++ type in yacc
  std::string *cpp_string;
}

%token <cpp_string> WORD
%token <cpp_string> PARAWORD
%token NOTOKEN GREAT NEWLINE GREATGREAT PIPE AMPERSAND TWOGREAT LESS GREATAMPERSAND GREATGREATAMPERSAND NOTHING

%{
//#define yylex yylex
#include <cstdio>
#include <string.h>
#include <string>
#include <vector>
#include <algorithm>
#include <stdlib.h>
#include <sys/types.h>
#include <dirent.h>
#include <regex.h>
#include "shell.hh"

#define MAXFILENAME 1024

std::vector<std::string> expand_wild_list;

extern void myunputc(int);
extern void expand_wildcards_ifnec(std::string *);
extern void expand_wildcards(std::string, std::string);
void yyerror(const char * s);
int yylex();

%}



%%

goal:
  commands
  ;

commands:
  command
  | commands command
  ;

command: simple_command
       ;

simple_command:	
  command_and_args pipe_command iomodifier_opt background_optional NEWLINE {
    /*printf("   Yacc: Execute command\n");*/
    Shell::_currentCommand.execute();
  }
  | NEWLINE 
  | error NEWLINE { yyerrok; }
  ;

command_and_args:
  command_word argument_list {
    Shell::_currentCommand.
    insertSimpleCommand( Command::_currSimpleCommand );
  }
  ;

argument_list:
  argument_list argument
  | /* can be empty */
  ;

argument:
  WORD {
    /*printf("   Yacc: insert argument \"%s\"\n", $1->c_str());*/
    expand_wildcards_ifnec( $1 );
  }
  | PARAWORD {
    $1->erase($1->begin() + $1->size() - 1);
    $1->erase($1->begin() + 0);
    Command::_currSimpleCommand->insertArgument( $1 );
  }
  ;

command_word:
  WORD {
    /*printf("   Yacc: insert command \"%s\"\n", $1->c_str());*/
    Command::_currSimpleCommand = new SimpleCommand();
    Command::_currSimpleCommand->insertArgument( $1 );
  }
  | PARAWORD {
    Command::_currSimpleCommand = new SimpleCommand();
    $1->erase($1->begin() + $1->size() - 1);
    $1->erase($1->begin() + 0);
    Command::_currSimpleCommand->insertArgument( $1 );
  }
  ;

pipe_command:
  PIPE command_and_args pipe_command
  | NOTHING pipe_command
  | /* can be empty */
  ;

iomodifier_opt:
  iomodifier_opt iomodifier
  | NOTHING iomodifier_opt
  | /* can be empty */
  ;

iomodifier:
  GREAT WORD {
    /*printf("   Yacc: insert output \"%s\"\n", $2->c_str());*/
    Shell::_currentCommand._outFileName = $2;
    Shell::_currentCommand._outRedirect++;
  }
  | GREAT PARAWORD {
    $2->erase($2->begin() + $2->size() - 1);
    $2->erase($2->begin() + 0);
    Shell::_currentCommand._outFileName = $2;
    Shell::_currentCommand._outRedirect++;
  }
  | GREATGREAT WORD {
    /*printf("   Yacc: append output \"%s\"\n", $2->c_str());*/
    Shell::_currentCommand._outFileName = $2;
    Shell::_currentCommand._append_out = true;
    Shell::_currentCommand._outRedirect++;
  }
  | GREATGREAT PARAWORD {
    $2->erase($2->begin() + $2->size() - 1);
    $2->erase($2->begin() + 0);
    Shell::_currentCommand._outFileName = $2;
    Shell::_currentCommand._append_out = true;
    Shell::_currentCommand._outRedirect++;
  }
  | GREATGREATAMPERSAND WORD {
    /*printf("   Yacc: append output and set background \"%s\"\n", $2->c_str());*/
    Shell::_currentCommand._outFileName = $2;
    Shell::_currentCommand._errFileName = $2;
    Shell::_currentCommand._append_out = true;
    Shell::_currentCommand._append_err = true;
    Shell::_currentCommand._outRedirect++;
  }
  | GREATGREATAMPERSAND PARAWORD {
    $2->erase($2->begin() + $2->size() - 1);
    $2->erase($2->begin() + 0);
    Shell::_currentCommand._outFileName = $2;
    Shell::_currentCommand._errFileName = $2;
    Shell::_currentCommand._append_out = true;
    Shell::_currentCommand._append_err = true;
    Shell::_currentCommand._outRedirect++;
  }
  | GREATAMPERSAND WORD {
    /*printf("   Yacc: insert output and set background \"%s\"\n", $2->c_str());*/
    Shell::_currentCommand._outFileName = $2;
    Shell::_currentCommand._errFileName = $2;
    Shell::_currentCommand._outRedirect++;
  }
  | GREATAMPERSAND PARAWORD {
    $2->erase($2->begin() + $2->size() - 1);
    $2->erase($2->begin() + 0);
    Shell::_currentCommand._outFileName = $2;
    Shell::_currentCommand._errFileName = $2;
    Shell::_currentCommand._outRedirect++;
  }
  | LESS WORD {
    /*printf("   Yacc: define intput \"%s\"\n", $2->c_str());*/
    Shell::_currentCommand._inFileName = $2;
  }
  | LESS PARAWORD {
    $2->erase($2->begin() + $2->size() - 1);
    $2->erase($2->begin() + 0);
    Shell::_currentCommand._inFileName = $2;
  }
  | TWOGREAT WORD {
    /*printf("   Yacc: define stderr \"%s\"\n", $2->c_str());*/
    Shell::_currentCommand._errFileName = $2;
  }
  | TWOGREAT PARAWORD {
    $2->erase($2->begin() + $2->size() - 1);
    $2->erase($2->begin() + 0);
    Shell::_currentCommand._errFileName = $2;
  }
  ;

background_optional:
  AMPERSAND {
    /*printf("   Yacc: set background\n");*/
    Shell::_currentCommand._backgnd = true;
  }
  | /*empty*/
  ;

%%

void expand_wildcards_ifnec( std::string * arg ) {
  if ( arg->find("*") == -1 && arg->find("?") == -1 && arg->find("~") == -1 ) {
    Command::_currSimpleCommand->insertArgument( arg );
  }
  else {
    expand_wildcards( "", *arg );
    std::sort(expand_wild_list.begin(), expand_wild_list.end());
    if ( expand_wild_list.size() == 0 ) {
      Command::_currSimpleCommand->insertArgument( arg );
      return;
    }
    while ( expand_wild_list.size() > 0 ) {
      std::string *cur_arg = new std::string(expand_wild_list[0]);
      Command::_currSimpleCommand->insertArgument(cur_arg);
      expand_wild_list.erase(expand_wild_list.begin() + 0);
    }
  }
}

void expand_wildcards( std::string prefix, std::string suffix ) {
  int start_w_dot = 0;
  std::string newPrefix;
  if ( suffix.size() == 0 ) {
    expand_wild_list.push_back(prefix);
    return;
  }
  if ( suffix.find("/") == -1 ) {
    newPrefix = suffix;
    suffix = "";
  }
  else {
    newPrefix = suffix.substr(0, suffix.find("/"));
    suffix = suffix.substr(suffix.find("/") + 1);
  }
  if ( newPrefix.find("*") == -1 && newPrefix.find("?") == -1 && newPrefix.find("~") == -1 ) {
    if ( suffix.size() != 0 ) {
      expand_wildcards(prefix + newPrefix + "/", suffix);
      return;
    }
    else {
      expand_wildcards(prefix + newPrefix, suffix);
      return;

    }
  }
  else {
    if ( newPrefix.size() == 1 && newPrefix.at(0) == '~' ) {
      newPrefix = getenv("HOME");
      expand_wildcards(prefix + newPrefix + "/", suffix);
      return;
    }
    else if ( newPrefix.size() >= 2 && newPrefix.at(0) == '~' ) {
      newPrefix.erase(newPrefix.begin() + 0);
      prefix = "/homes/";
      if ( newPrefix.find("*") == -1 && newPrefix.find("?") == -1 ) {
        if ( suffix.size() != 0 ) {
          expand_wildcards(prefix + newPrefix + "/", suffix);
          return;
        }
        else {
          expand_wildcards(prefix + newPrefix, suffix);
          return;
        }
      }
    }
    for ( int i = 0; i < newPrefix.size(); i++ ) {
      if ( newPrefix.at(i) == '?' ) {
        newPrefix.erase(newPrefix.begin() + i);
        newPrefix.insert(i, ".");
      }
      else if ( newPrefix.at(i) == '*' ) {
        newPrefix.erase(newPrefix.begin() + i);
        newPrefix.insert(i, ".*");
        i++;
      }
      else if ( newPrefix.at(i) == '.' ) {
        newPrefix.erase(newPrefix.begin() + i);
        newPrefix.insert(i, "\\.");
        i++;
      }
    }
  }
  if ( newPrefix.size() >= 1 ) {
    if ( newPrefix.at(0) == '\\' && newPrefix.at(1) == '.' ) {
      start_w_dot = 1;
    }
  }
  newPrefix.insert(0, "^");
  newPrefix.append("$");
  regex_t reg_exp;
  int reg_work = regcomp(&reg_exp, newPrefix.c_str(), REG_EXTENDED|REG_NOSUB);
  if ( reg_work != 0 ) {
    fprintf(stderr, "regcomp");
    return;
  }
  regmatch_t reg_mat;
  DIR * dir;
  if ( prefix.size() == 0 ) {
    dir = opendir(".");
  }
  else {
    dir = opendir(prefix.c_str());
  }
  if (dir == NULL) {
    fprintf(stderr, "opendir");
    return;
  }
  struct dirent * ent;
  char buffer[MAXFILENAME];
  while ( (ent = readdir(dir)) != NULL ) {
    if ( regexec(&reg_exp, ent->d_name, 1, &reg_mat, 0) == 0 ) {
      if ( suffix.size() == 0 ) {
        if ( ent->d_name[0] == '.' && start_w_dot == 1 ) {
          sprintf(buffer, "%s", ent->d_name);
          std::string plus_prefix(buffer);
          expand_wildcards(prefix + plus_prefix, suffix);
        }
        else if ( ent->d_name[0] != '.' ) {
          sprintf(buffer, "%s", ent->d_name);
          std::string plus_prefix(buffer);
          expand_wildcards(prefix + plus_prefix, suffix);
        }
      }
      else {
        if ( ent->d_type == DT_DIR ) {
          if ( ent->d_name[0] == '.' && start_w_dot == 1 ) {
            sprintf(buffer, "%s", ent->d_name);
            std::string plus_prefix(buffer);
            expand_wildcards(prefix + plus_prefix + "/", suffix);
          }
          else if ( ent->d_name[0] != '.' ) {
            sprintf(buffer, "%s", ent->d_name);
            std::string plus_prefix(buffer);
            expand_wildcards(prefix + plus_prefix + "/", suffix);
          }
        }
      }
    }
  }
  closedir(dir);
}

void
yyerror(const char * s)
{
  fprintf(stderr,"%s", s);
}

#if 0
main()
{
  yyparse();
}
#endif
