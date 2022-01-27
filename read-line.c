/*
 * CS252: Systems Programming
 * Purdue University
 * Example that shows how to read one line with simple editing
 * using raw terminal.
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define MAX_BUFFER_LINE 2048
#define MAX_SAVED 256

extern void tty_raw_mode(void);

// Buffer where line is stored
int line_length;
int cur_char;
char line_buffer[MAX_BUFFER_LINE];

// Simple history array
// This history does not change. 
// Yours have to be updated.
int history_index = 0;

char * history [MAX_SAVED];


int history_length = 0;

void read_line_print_usage()
{
  char * usage = "\n"
    " ctrl-?       Print usage\n"
    " Backspace    Deletes last character\n"
    " up arrow     See last command in the history\n";

  write(1, usage, strlen(usage));
}

/* 
 * Input a line with some basic editing.
 */
char * read_line() {

  // Set terminal in raw mode
  tty_raw_mode();

  line_length = 0;

  cur_char = 0;

  // Read one line until enter is typed
  while (1) {

    // Read one character in raw mode.
    char ch;
    read(0, &ch, 1);

    if (ch>=32 && ch != 127) {
      // It is a printable character. 
      // If max number of character reached return.
      if (line_length==MAX_BUFFER_LINE-2) break; 

      // add char to buffer
      if ( line_length == cur_char ) {
        line_buffer[cur_char]=ch;
        line_length++;
        cur_char++;
        write(1, &ch, 1);
      }
      else {
        for ( int i = line_length; i >= cur_char; i-- ) {
          line_buffer[i+1] = line_buffer[i];
        }
        line_buffer[cur_char]=ch;
        char temp;
        for ( int i = cur_char; i > 0; i-- ) {
          temp = 27;
          write(1, &temp, 1);
          temp = 91;
          write(1, &temp, 1);
          temp = 68;
          write(1, &temp, 1);
        }
        for ( int i = 0; i <= line_length; i++ ) {
          temp = ' ';
          write (1, &temp, 1);
        }
        for ( int i = line_length; i >= 0; i-- ) {
          temp = 27;
          write(1, &temp, 1);
          temp = 91;
          write(1, &temp, 1);
          temp = 68;
          write(1, &temp, 1);
        }
        line_length++;
        write (1, line_buffer, line_length);
        cur_char++;
        for ( int i = line_length; i > cur_char; i-- ) {
          temp = 27;
          write(1, &temp, 1);
          temp = 91;
          write(1, &temp, 1);
          temp = 68;
          write(1, &temp, 1);
        }
      }
    }
    else if (ch==10) {
      // <Enter> was typed. Return line
      history[history_length] = malloc(line_length + 1);
      strncpy(history[history_length], line_buffer, line_length);
      history[history_length][line_length] = '\0';
      history_length++;
      history_index = history_length;
      // Print newline
      write(1,&ch,1);

      break;
    }
    else if (ch == 31) {
      // ctrl-?
      read_line_print_usage();
      line_buffer[0]=0;
      break;
    }
    else if (ch == 8 || ch == 127) {
      // <backspace> was typed. Remove previous character read.
      if ( cur_char != 0 ) {
        for ( int i = cur_char - 1; i < line_length - 1; i++ ) {
          line_buffer[i] = line_buffer[i + 1];
        }
        char temp;
        for ( int i = cur_char; i > 0; i-- ) {
          temp = 27;
          write(1, &temp, 1);
          temp = 91;
          write(1, &temp, 1);
          temp = 68;
          write(1, &temp, 1);
        }

        for ( int i = 0; i <= line_length; i++ ) {
          temp = ' ';
          write(1, &temp, 1);
        }
        
        for ( int i = line_length; i >= 0; i-- ) {
          temp = 8;
          write(1, &temp, 1);
        }

        // Remove one character from buffer
        line_length--;
        write(1, line_buffer, line_length);
        cur_char--;
        for ( int i = line_length; i > cur_char; i-- ) {
          temp = 8;
          write(1, &temp, 1);
        }
      }
    }
    else if ( ch == 4 ) {
      if ( cur_char != 0 ) {
        for ( int i = cur_char; i < line_length - 1; i++ ) {
          line_buffer[i] = line_buffer[i + 1];
        }
        char temp;
        for ( int i = cur_char; i > 0; i-- ) {
          temp = 27;
          write(1, &temp, 1);
          temp = 91;
          write(1, &temp, 1);
          temp = 68;
          write(1, &temp, 1);
        }

        for ( int i = 0; i <= line_length; i++ ) {
          temp = ' ';
          write(1, &temp, 1);
        }
        
        for ( int i = line_length; i >= 0; i-- ) {
          temp = 8;
          write(1, &temp, 1);
        }

        // Remove one character from buffer
        line_length--;
        write(1, line_buffer, line_length);
        cur_char--;
        for ( int i = line_length; i > cur_char; i-- ) {
          temp = 8;
          write(1, &temp, 1);
        }
      }
    }

    else if ( ch == 1 ) {
      for ( int i = cur_char; i > 0; i-- ) {
        ch = 27;
        write(1, &ch, 1);
        ch = 91;
        write(1, &ch, 1);
        ch = 68;
        write(1, &ch, 1);
      }
      cur_char = 0;
    }
    else if ( ch == 5 ) {
      for ( int i = cur_char; i < line_length; i++ ) {
        ch = 27;
        write(1, &ch, 1);
        ch = 91;
        write(1, &ch, 1);
        ch = 67;
        write(1, &ch, 1);
      }
      cur_char = line_length;
    }
    else if (ch==27) {
      // Escape sequence. Read two chars more
      //
      // HINT: Use the program "keyboard-example" to
      // see the ascii code for the different chars typed.
      //
      char ch1; 
      char ch2;
      read(0, &ch1, 1);
      read(0, &ch2, 1);
      if (ch1==91 && ch2==65) {
	// Up arrow. Print next line in history.
        if ( history_index > 0 ) {
	// Erase old line
	// Print backspaces
        for ( int i = cur_char; i > 0; i-- ) {
          char temp = 27;
          write (1, &temp, 1);
          temp = 91;
          write (1, &temp, 1);
          temp = 68;
          write (1, &temp, 1);
        }

	// Print spaces on top
	      for (int i =0; i <= line_length; i++) {
	        ch = ' ';
	        write(1,&ch,1);
	      }

	// Print backspaces
	      for (int i =0; i <= line_length; i++) {
	        ch = 8;
	        write(1,&ch,1);
	      }	

	// Copy line from history
          history_index--;
	        strcpy(line_buffer, history[history_index]);
	        line_length = strlen(line_buffer);
	// echo line
	        write(1, line_buffer, line_length);
          cur_char = line_length;
        }
     }
     else if ( ch1 == 91 && ch2 == 66) {
       if ( history_index < history_length - 1 ) {
       for ( int i = cur_char; i > 0; i-- ) {
          char temp = 27;
          write (1, &temp, 1);
          temp = 91;
          write (1, &temp, 1);
          temp = 68;
          write (1, &temp, 1);
       }

       for ( int i = 0; i <= line_length; i++ ) {
          ch = ' ';
          write(1, &ch, 1);
       }

       for ( int i = 0; i <= line_length; i++ ) {
          ch = 8;
          write(1, &ch, 1);
       }
          history_index++;
          strcpy(line_buffer, history[history_index]);
          line_length = strlen(line_buffer);
          write(1, line_buffer, line_length);
          cur_char = line_length;
       }
     }
     else if ( ch1 == 91 && ch2 == 68) {
        if ( cur_char > 0 ) {
          char temp;
          temp = 27;
          write (1, &temp, 1);
          write (1, &ch1, 1);
          write (1, &ch2, 1);
          cur_char--;
        }
     }
     else if ( ch1 == 91 && ch2 == 67) {
        if ( cur_char < line_length ) {
          char temp;
          temp = 27;
          write (1, &temp, 1);
          write (1, &ch1, 1);
          write (1, &ch2, 1);
          cur_char++;
        }

      }
    }

  }

  // Add eol and null char at the end of string
  line_buffer[line_length]=10;
  line_length++;
  line_buffer[line_length]=0;

  return line_buffer;
}

