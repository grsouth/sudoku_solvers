#include <stdio.h>
#include <stdlib.h>
#include <time.h>

typedef struct {
    char puzzle[82];
    unsigned short rows[9];
    unsigned short cols[9];
    unsigned short boxes[9];
} Sudoku;

int solve(Sudoku *s);
int find_best_cell(const Sudoku *s);
void print_puzzle(const char puzzle[82]);
double timespec_elapsed_ms(struct timespec start, struct timespec end);

int main(int argc, char *argv[]) {
    printf("sudoku solver (c)\n");

    /////////////////
    // LOAD PUZZLE //
    /////////////////
    
    // check to see if args
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <easy|hard> [repeat_count]\n", argv[0]);
        return 1;
    }

    // figure out how many times to repeat (for benchmarking)
    int repeat_count = 1;
    if (argc >= 3) {
        repeat_count = atoi(argv[2]);
        if (repeat_count < 1) {
            fprintf(stderr, "repeat_count must be at least 1\n");
            return 1;
        }
    }

    // choose puzzle
    const char *puzzle_file;
    if (argv[1][0] == 'e') {
        puzzle_file = "../puzzles/easy.txt";
    } else if (argv[1][0] == 'h') {
        puzzle_file = "puzzles/hard.txt";
    } else {
        fprintf(stderr, "Invalid option. Use 'easy' or 'hard'\n");
        return 1;
    }

    // open file
    FILE *fp = fopen(puzzle_file, "r");
    
    // Handle file opening error
    if (fp == NULL) {
        fprintf(stderr, "Error opening file\n");
        return 1;
    }

    // read file into one big string
    Sudoku sudoku = {0};
    if (fgets(sudoku.puzzle, sizeof(sudoku.puzzle), fp) == NULL) {
        fprintf(stderr, "Error reading file\n");
        fclose(fp);
        return 1;
    }

    // close file
    fclose(fp);

    char original_puzzle[82];
    for (int i = 0; i < 82; i++) {
        original_puzzle[i] = sudoku.puzzle[i];
    }

    // parse puzzle and fill in bits
    // look through each character in the puzzle string.
    for (int i = 0; i < 81; i++) {
        char c = sudoku.puzzle[i];
        if (c >= '1' && c <= '9') {
            // figure out which row, column, and box this number belongs to.
            int num = c - '1'; // 0-8 instead of 1-9
            int row = i / 9;
            int col = i % 9;
            int box = (row / 3) * 3 + (col / 3);
            unsigned short bit = 1 << num;
            sudoku.rows[row] |= bit;
            sudoku.cols[col] |= bit;
            sudoku.boxes[box] |= bit;
        }
    }

    //////////////////
    // SOLVE PUZZLE //
    //////////////////

    int solved = 0;
    double elapsed_ms = 0.0;

    if (repeat_count == 1) {
        struct timespec start;
        struct timespec end;
        clock_gettime(CLOCK_MONOTONIC, &start);
        solved = solve(&sudoku);
        clock_gettime(CLOCK_MONOTONIC, &end);
        elapsed_ms = timespec_elapsed_ms(start, end);
    } else {
        struct timespec start;
        struct timespec end;
        clock_gettime(CLOCK_MONOTONIC, &start);

        for (int run = 0; run < repeat_count; run++) {
            Sudoku benchmark = sudoku;
            solved = solve(&benchmark);
            if (!solved) {
                break;
            }
        }

        clock_gettime(CLOCK_MONOTONIC, &end);
        elapsed_ms = timespec_elapsed_ms(start, end);
    }

    if (!solved) {
        fprintf(stderr, "No solution found\n");
    } else {
        if (repeat_count == 1) {
            printf("Initial puzzle:\n");
            print_puzzle(original_puzzle);
            printf("\nSolved puzzle:\n");
            print_puzzle(sudoku.puzzle);
            printf("\nSolved in %.3f ms\n", elapsed_ms);
        } else { // if benchmarking, skip the pretty print and just show the timing results
            printf("Solved %d runs in %.3f s\n", repeat_count, elapsed_ms / 1000.0);
            printf("Average: %.6f ms per run\n", elapsed_ms / repeat_count);
        }
    }
    return 0;
}

int solve(Sudoku *s) {
    int index = find_best_cell(s);

    if (index == -1) {
        // no empty cells, puzzle solved
        return 1;
    }

    int row = index / 9;
    int col = index % 9;
    int box = (row / 3) * 3 + (col / 3);
    unsigned short used = s->rows[row] | s->cols[col] | s->boxes[box];
    unsigned short available = 0x1FF & ~used; // bits for digits 1-9

    for (int num = 0; num < 9; num++) {
        if (available & (1 << num)) { // if this digit is available
            // place the digit
            char c = '1' + num;
            s->puzzle[index] = c;
            unsigned short bit = 1 << num;
            s->rows[row] |= bit;
            s->cols[col] |= bit;
            s->boxes[box] |= bit;

            // recursively solve the rest of the puzzle
            if (solve(s)) {
                return 1; // solution found
            }

            // backtrack
            s->puzzle[index] = '0';
            s->rows[row] &= ~bit;
            s->cols[col] &= ~bit;
            s->boxes[box] &= ~bit;
        }
    }

    return 0; // no solution found
}

int find_best_cell(const Sudoku *s) {
    // loop through all cells and find the one with the fewest possibilities
    int best_index = -1;
    int best_count = 10; // more than the max possible (9)
    for (int i = 0; i < 81; i++) {
        if (s->puzzle[i] == '0') { // if cell is empty
            int row = i / 9;
            int col = i % 9;
            int box = (row / 3) * 3 + (col / 3);
            unsigned short used = s->rows[row] | s->cols[col] | s->boxes[box];
            unsigned short available = 0x1FF & ~used;
            int count = __builtin_popcount(available); // count legal digits
            if (count < best_count) {
                best_count = count;
                best_index = i;
            }
        }
    }
    return best_index;
}

// print the puzzle in a pretty way.
// Like this:
// 5 3 - | - 7 - | - - -
// 6 - - | 1 9 5 | - - -
// - 9 8 | - - - | - 6 -
// ------+-------+------
// 8 - - | - 6 - | - - 3
// 4 - - | 8 - 3 | - - 1
// 7 - - | - 2 - | - - 6
// ------+-------+------
// - 6 - | - - - | 2 8 -
// - - - | 4 1 9 | - - 5    
void print_puzzle(const char puzzle[82]) {
    for (int i = 0; i < 81; i++) {
        char c = puzzle[i];
        if (c == '0') {
            c = '-';
        }

        printf("%c", c);

        if (i % 9 != 8) {
            printf(" ");
        }

        if (i % 9 == 2 || i % 9 == 5) {
            printf("| ");
        }

        if (i % 9 == 8) {
            printf("\n");
            if (i == 26 || i == 53) {
                printf("------+-------+------\n");
            }
        }
    }
}

double timespec_elapsed_ms(struct timespec start, struct timespec end) {
    time_t seconds = end.tv_sec - start.tv_sec;
    long nanoseconds = end.tv_nsec - start.tv_nsec;
    return (double)seconds * 1000.0 + (double)nanoseconds / 1000000.0;
}
