package main

import "core:fmt"
import "core:math/bits"
import "core:os"
import "core:strconv"
import "core:time"

Sudoku :: struct {
	puzzle: [82]u8,
	rows:   [9]u16,
	cols:   [9]u16,
	boxes:  [9]u16,
}

main :: proc() {
	fmt.println("sudoku solver (odin)")

	if len(os.args) < 2 {
		fmt.eprintfln("Usage: %s <easy|hard> [repeat_count]", os.args[0])
		os.exit(1)
	}

	repeat_count := 1
	if len(os.args) >= 3 {
		value, ok := strconv.parse_int(os.args[2], 10)
		if !ok || value < 1 {
			fmt.eprintln("repeat_count must be at least 1")
			os.exit(1)
		}
		repeat_count = value
	}

	puzzle_file := ""
	if os.args[1][0] == 'e' {
		puzzle_file = "../puzzles/easy.txt"
	} else if os.args[1][0] == 'h' {
		puzzle_file = "puzzles/hard.txt"
	} else {
		fmt.eprintln("Invalid option. Use 'easy' or 'hard'")
		os.exit(1)
	}

	data, err := os.read_entire_file(puzzle_file, context.allocator)
	if err != nil {
		fmt.eprintln("Error opening file")
		os.exit(1)
	}

	if len(data) < 81 {
		fmt.eprintln("Error reading file")
		os.exit(1)
	}

	sudoku := Sudoku{}
	for i in 0..<81 {
		sudoku.puzzle[i] = data[i]
	}

	original_puzzle := sudoku.puzzle

	for i in 0..<81 {
		c := sudoku.puzzle[i]
		if c >= '1' && c <= '9' {
			num := c - '1'
			row := i / 9
			col := i % 9
			box := (row / 3) * 3 + (col / 3)
			bit := u16(1) << u16(num)
			sudoku.rows[row] |= bit
			sudoku.cols[col] |= bit
			sudoku.boxes[box] |= bit
		}
	}

	solved := false
	elapsed_ms := 0.0

	if repeat_count == 1 {
		start := time.tick_now()
		solved = solve(&sudoku)
		elapsed_ms = time.duration_milliseconds(time.tick_since(start))
	} else {
		start := time.tick_now()
		for _ in 0..<repeat_count {
			benchmark := sudoku
			solved = solve(&benchmark)
			if !solved {
				break
			}
		}
		elapsed_ms = time.duration_milliseconds(time.tick_since(start))
	}

	if !solved {
		fmt.eprintln("No solution found")
	} else if repeat_count == 1 {
		fmt.println("Initial puzzle:")
		print_puzzle(original_puzzle)
		fmt.println()
		fmt.println("Solved puzzle:")
		print_puzzle(sudoku.puzzle)
		fmt.println()
		fmt.printfln("Solved in %.3f ms", elapsed_ms)
	} else {
		fmt.printfln("Solved %d runs in %.3f s", repeat_count, elapsed_ms/1000.0)
		fmt.printfln("Average: %.6f ms per run", elapsed_ms/f64(repeat_count))
	}
}

solve :: proc(s: ^Sudoku) -> bool {
	index := find_best_cell(s)
	if index == -1 {
		return true
	}

	row := index / 9
	col := index % 9
	box := (row / 3) * 3 + (col / 3)
	used := s.rows[row] | s.cols[col] | s.boxes[box]
	available := u16(0x01FF) & ~used

	for num in 0..<9 {
		bit := u16(1) << u16(num)
		if (available & bit) != 0 {
			s.puzzle[index] = u8('1') + u8(num)
			s.rows[row] |= bit
			s.cols[col] |= bit
			s.boxes[box] |= bit

			if solve(s) {
				return true
			}

			s.puzzle[index] = '0'
			s.rows[row] &= ~bit
			s.cols[col] &= ~bit
			s.boxes[box] &= ~bit
		}
	}

	return false
}

find_best_cell :: proc(s: ^Sudoku) -> int {
	best_index := -1
	best_count := 10

	for i in 0..<81 {
		if s.puzzle[i] == '0' {
			row := i / 9
			col := i % 9
			box := (row / 3) * 3 + (col / 3)
			used := s.rows[row] | s.cols[col] | s.boxes[box]
			available := u16(0x01FF) & ~used
			count := int(bits.count_ones(available))
			if count < best_count {
				best_count = count
				best_index = i
			}
		}
	}

	return best_index
}

print_puzzle :: proc(puzzle: [82]u8) {
	for i in 0..<81 {
		c := puzzle[i]
		if c == '0' {
			c = '-'
		}

		fmt.printf("%c", c)

		if i % 9 != 8 {
			fmt.print(" ")
		}

		if i % 9 == 2 || i % 9 == 5 {
			fmt.print("| ")
		}

		if i % 9 == 8 {
			fmt.println()
			if i == 26 || i == 53 {
				fmt.println("------+-------+------")
			}
		}
	}
}
