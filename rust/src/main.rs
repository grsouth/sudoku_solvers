use std::env;
use std::fs::File;
use std::io::{self, BufRead, BufReader, Write};
use std::process;
use std::time::Instant;

struct Sudoku {
    puzzle: [u8; 82],
    rows: [u16; 9],
    cols: [u16; 9],
    boxes: [u16; 9],
}

fn solve(s: &mut Sudoku) -> bool {
    let index = find_best_cell(s);

    if index == -1 {
        // no empty cells, puzzle solved
        return true;
    }

    let index = index as usize;
    let row = index / 9;
    let col = index % 9;
    let box_index = (row / 3) * 3 + (col / 3);
    let used = s.rows[row] | s.cols[col] | s.boxes[box_index];
    let available = 0x01FFu16 & !used; // bits for digits 1-9

    for num in 0..9 {
        let bit = 1u16 << num;
        if available & bit != 0 {
            // place the digit
            let c = b'1' + num as u8;
            s.puzzle[index] = c;
            s.rows[row] |= bit;
            s.cols[col] |= bit;
            s.boxes[box_index] |= bit;

            // recursively solve the rest of the puzzle
            if solve(s) {
                return true; // solution found
            }

            // backtrack
            s.puzzle[index] = b'0';
            s.rows[row] &= !bit;
            s.cols[col] &= !bit;
            s.boxes[box_index] &= !bit;
        }
    }

    false // no solution found
}

fn find_best_cell(s: &Sudoku) -> isize {
    // loop through all cells and find the one with the fewest possibilities
    let mut best_index = -1;
    let mut best_count = 10;

    for i in 0..81 {
        if s.puzzle[i] == b'0' {
            // if cell is empty
            let row = i / 9;
            let col = i % 9;
            let box_index = (row / 3) * 3 + (col / 3);
            let used = s.rows[row] | s.cols[col] | s.boxes[box_index];
            let available = 0x01FFu16 & !used;
            let count = available.count_ones() as i32; // count legal digits

            if count < best_count {
                best_count = count;
                best_index = i as isize;
            }
        }
    }

    best_index
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
fn print_puzzle(puzzle: &[u8; 82]) {
    let stdout = io::stdout();
    let mut out = stdout.lock();

    for (i, byte) in puzzle.iter().copied().take(81).enumerate() {
        let mut c = byte;
        if c == b'0' {
            c = b'-';
        }

        write!(out, "{}", c as char).expect("failed to write puzzle output");

        if i % 9 != 8 {
            write!(out, " ").expect("failed to write puzzle spacing");
        }

        if i % 9 == 2 || i % 9 == 5 {
            write!(out, "| ").expect("failed to write puzzle divider");
        }

        if i % 9 == 8 {
            writeln!(out).expect("failed to write puzzle newline");
            if i == 26 || i == 53 {
                writeln!(out, "------+-------+------").expect("failed to write puzzle separator");
            }
        }
    }
}

fn main() {
    println!("sudoku solver (rust)");

    /////////////////
    // LOAD PUZZLE //
    /////////////////

    let args: Vec<String> = env::args().collect();

    // check to see if args
    if args.len() < 2 {
        eprintln!("Usage: {} <easy|hard> [repeat_count]", args[0]);
        process::exit(1);
    }

    // figure out how many times to repeat (for benchmarking)
    let mut repeat_count = 1usize;
    if args.len() >= 3 {
        repeat_count = args[2].parse::<usize>().unwrap_or(0);
        if repeat_count < 1 {
            eprintln!("repeat_count must be at least 1");
            process::exit(1);
        }
    }

    // choose puzzle
    let puzzle_file;
    if args[1].starts_with('e') {
        puzzle_file = "../puzzles/easy.txt";
    } else if args[1].starts_with('h') {
        puzzle_file = "puzzles/hard.txt";
    } else {
        eprintln!("Invalid option. Use 'easy' or 'hard'");
        process::exit(1);
    }

    // open file
    let file = match File::open(puzzle_file) {
        Ok(file) => file,
        Err(_) => {
            eprintln!("Error opening file");
            process::exit(1);
        }
    };

    // read file into one big string
    let mut sudoku = Sudoku {
        puzzle: [0; 82],
        rows: [0; 9],
        cols: [0; 9],
        boxes: [0; 9],
    };
    let mut reader = BufReader::new(file);
    let mut line = String::new();
    if reader.read_line(&mut line).is_err() || line.is_empty() {
        eprintln!("Error reading file");
        process::exit(1);
    }

    let bytes = line.as_bytes();
    for i in 0..81 {
        sudoku.puzzle[i] = if i < bytes.len() { bytes[i] } else { 0 };
    }

    let original_puzzle = sudoku.puzzle;

    // parse puzzle and fill in bits
    // look through each character in the puzzle string.
    for i in 0..81 {
        let c = sudoku.puzzle[i];
        if (b'1'..=b'9').contains(&c) {
            // figure out which row, column, and box this number belongs to.
            let num = c - b'1'; // 0-8 instead of 1-9
            let row = i / 9;
            let col = i % 9;
            let box_index = (row / 3) * 3 + (col / 3);
            let bit = 1u16 << num;
            sudoku.rows[row] |= bit;
            sudoku.cols[col] |= bit;
            sudoku.boxes[box_index] |= bit;
        }
    }

    //////////////////
    // SOLVE PUZZLE //
    //////////////////

    let mut solved = false;
    let elapsed_ms;

    if repeat_count == 1 {
        let start = Instant::now();
        solved = solve(&mut sudoku);
        elapsed_ms = start.elapsed().as_secs_f64() * 1000.0;
    } else {
        let start = Instant::now();

        for _run in 0..repeat_count {
            let mut benchmark = Sudoku {
                puzzle: sudoku.puzzle,
                rows: sudoku.rows,
                cols: sudoku.cols,
                boxes: sudoku.boxes,
            };
            solved = solve(&mut benchmark);
            if !solved {
                break;
            }
        }

        elapsed_ms = start.elapsed().as_secs_f64() * 1000.0;
    }

    if !solved {
        eprintln!("No solution found");
    } else if repeat_count == 1 {
        println!("Initial puzzle:");
        print_puzzle(&original_puzzle);
        println!();
        println!("Solved puzzle:");
        print_puzzle(&sudoku.puzzle);
        println!();
        println!("Solved in {:.3} ms", elapsed_ms);
    } else {
        // if benchmarking, skip the pretty print and just show the timing results
        println!("Solved {} runs in {:.3} s", repeat_count, elapsed_ms / 1000.0);
        println!("Average: {:.6} ms per run", elapsed_ms / repeat_count as f64);
    }
}
