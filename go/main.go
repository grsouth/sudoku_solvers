package main

import (
	"fmt"
	"math/bits"
	"os"
	"strconv"
	"time"
)

type Sudoku struct {
	puzzle [82]byte
	rows   [9]uint16
	cols   [9]uint16
	boxes  [9]uint16
}

func main() {
	fmt.Println("sudoku solver (go)")

	/////////////////
	// LOAD PUZZLE //
	/////////////////

	// check to see if args
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s <easy|hard> [repeat_count]\n", os.Args[0])
		os.Exit(1)
	}

	// figure out how many times to repeat (for benchmarking)
	repeat_count := 1
	if len(os.Args) >= 3 {
		value, err := strconv.Atoi(os.Args[2])
		if err != nil || value < 1 {
			fmt.Fprintln(os.Stderr, "repeat_count must be at least 1")
			os.Exit(1)
		}
		repeat_count = value
	}

	// choose puzzle
	var puzzle_file string
	if os.Args[1][0] == 'e' {
		puzzle_file = "../puzzles/easy.txt"
	} else if os.Args[1][0] == 'h' {
		puzzle_file = "puzzles/hard.txt"
	} else {
		fmt.Fprintln(os.Stderr, "Invalid option. Use 'easy' or 'hard'")
		os.Exit(1)
	}

	// open file and read file into one big string
	data, err := os.ReadFile(puzzle_file)
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error opening file")
		os.Exit(1)
	}

	var sudoku Sudoku
	if len(data) < 81 {
		fmt.Fprintln(os.Stderr, "Error reading file")
		os.Exit(1)
	}

	for i := 0; i < 81; i++ {
		sudoku.puzzle[i] = data[i]
	}

	var original_puzzle [82]byte
	for i := 0; i < 82; i++ {
		original_puzzle[i] = sudoku.puzzle[i]
	}

	// parse puzzle and fill in bits
	// look through each character in the puzzle string.
	for i := 0; i < 81; i++ {
		c := sudoku.puzzle[i]
		if c >= '1' && c <= '9' {
			// figure out which row, column, and box this number belongs to.
			num := c - '1' // 0-8 instead of 1-9
			row := i / 9
			col := i % 9
			box := (row/3)*3 + (col / 3)
			bit := uint16(1 << num)
			sudoku.rows[row] |= bit
			sudoku.cols[col] |= bit
			sudoku.boxes[box] |= bit
		}
	}

	//////////////////
	// SOLVE PUZZLE //
	//////////////////

	solved := false
	elapsed_ms := 0.0

	if repeat_count == 1 {
		start := time.Now()
		solved = solve(&sudoku)
		elapsed_ms = float64(time.Since(start)) / float64(time.Millisecond)
	} else {
		start := time.Now()
		for run := 0; run < repeat_count; run++ {
			benchmark := sudoku
			solved = solve(&benchmark)
			if !solved {
				break
			}
		}
		elapsed_ms = float64(time.Since(start)) / float64(time.Millisecond)
	}

	if !solved {
		fmt.Fprintln(os.Stderr, "No solution found")
	} else {
		if repeat_count == 1 {
			fmt.Println("Initial puzzle:")
			print_puzzle(original_puzzle)
			fmt.Println()
			fmt.Println("Solved puzzle:")
			print_puzzle(sudoku.puzzle)
			fmt.Printf("\nSolved in %.3f ms\n", elapsed_ms)
		} else { // if benchmarking, skip the pretty print and just show the timing results
			fmt.Printf("Solved %d runs in %.3f s\n", repeat_count, elapsed_ms/1000.0)
			fmt.Printf("Average: %.6f ms per run\n", elapsed_ms/float64(repeat_count))
		}
	}
}

func solve(s *Sudoku) bool {
	index := find_best_cell(s)
	if index == -1 {
		// no empty cells, puzzle solved
		return true
	}

	row := index / 9
	col := index % 9
	box := (row/3)*3 + (col / 3)
	used := s.rows[row] | s.cols[col] | s.boxes[box]
	available := uint16(0x1FF) &^ used

	for num := 0; num < 9; num++ {
		if available&(1<<num) != 0 { // if this digit is available
			// place the digit
			c := byte('1' + num)
			s.puzzle[index] = c
			bit := uint16(1 << num)
			s.rows[row] |= bit
			s.cols[col] |= bit
			s.boxes[box] |= bit

			// recursively solve the rest of the puzzle
			if solve(s) {
				return true // solution found
			}

			// backtrack
			s.puzzle[index] = '0'
			s.rows[row] &^= bit
			s.cols[col] &^= bit
			s.boxes[box] &^= bit
		}
	}

	return false // no solution found
}

func find_best_cell(s *Sudoku) int {
	// loop through all cells and find the one with the fewest possibilities
	best_index := -1
	best_count := 10 // more than the max possible (9)

	for i := 0; i < 81; i++ {
		if s.puzzle[i] == '0' { // if cell is empty
			row := i / 9
			col := i % 9
			box := (row/3)*3 + (col / 3)
			used := s.rows[row] | s.cols[col] | s.boxes[box]
			available := uint16(0x1FF) &^ used
			count := bits.OnesCount16(available) // count legal digits
			if count < best_count {
				best_count = count
				best_index = i
			}
		}
	}

	return best_index
}

func print_puzzle(puzzle [82]byte) {
	for i := 0; i < 81; i++ {
		c := puzzle[i]
		if c == '0' {
			c = '-'
		}

		fmt.Printf("%c", c)

		if i%9 != 8 {
			fmt.Print(" ")
		}

		if i%9 == 2 || i%9 == 5 {
			fmt.Print("| ")
		}

		if i%9 == 8 {
			fmt.Println()
			if i == 26 || i == 53 {
				fmt.Println("------+-------+------")
			}
		}
	}
}
