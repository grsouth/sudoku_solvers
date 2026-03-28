package main

import (
	"fmt"
	"math/bits"
	"os"
	"path/filepath"
	"strconv"
	"strings"
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

	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s <easy|hard> [repeat_count]\n", os.Args[0])
		os.Exit(1)
	}

	repeatCount := 1
	if len(os.Args) >= 3 {
		value, err := strconv.Atoi(os.Args[2])
		if err != nil || value < 1 {
			fmt.Fprintln(os.Stderr, "repeat_count must be at least 1")
			os.Exit(1)
		}
		repeatCount = value
	}

	puzzleFile := ""
	switch os.Args[1] {
	case "easy":
		puzzleFile = "puzzles/easy.txt"
	case "hard":
		puzzleFile = "puzzles/hard.txt"
	default:
		fmt.Fprintln(os.Stderr, "Invalid puzzle type. Use 'easy' or 'hard'.")
		os.Exit(1)
	}

	sudoku, err := loadSudoku(puzzleFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to load puzzle: %v\n", err)
		os.Exit(1)
	}

	originalPuzzle := sudoku.puzzle

	solved := false
	var elapsed time.Duration

	if repeatCount == 1 {
		start := time.Now()
		solved = solve(&sudoku)
		elapsed = time.Since(start)
	} else {
		start := time.Now()
		for run := 0; run < repeatCount; run++ {
			benchmark := sudoku
			solved = solve(&benchmark)
			if !solved {
				break
			}
		}
		elapsed = time.Since(start)
	}

	if !solved {
		fmt.Fprintln(os.Stderr, "No solution found")
		os.Exit(1)
	}

	if repeatCount == 1 {
		fmt.Println("Initial puzzle:")
		printPuzzle(originalPuzzle)
		fmt.Println()
		fmt.Println("Solved puzzle:")
		printPuzzle(sudoku.puzzle)
		fmt.Printf("\nSolved in %.3f ms\n", float64(elapsed)/float64(time.Millisecond))
		return
	}

	fmt.Printf("Solved %d runs in %.3f s\n", repeatCount, elapsed.Seconds())
	fmt.Printf("Average: %.6f ms per run\n", float64(elapsed)/float64(time.Millisecond)/float64(repeatCount))
}

func loadSudoku(path string) (Sudoku, error) {
	var sudoku Sudoku

	data, err := readPuzzleFile(path)
	if err != nil {
		return sudoku, err
	}

	puzzle := strings.TrimSpace(string(data))
	if len(puzzle) != 81 {
		return sudoku, fmt.Errorf("expected 81 characters, got %d", len(puzzle))
	}

	copy(sudoku.puzzle[:81], puzzle)

	for i := 0; i < 81; i++ {
		c := sudoku.puzzle[i]
		if c < '1' || c > '9' {
			continue
		}

		num := int(c - '1')
		row := i / 9
		col := i % 9
		box := (row/3)*3 + (col / 3)
		bit := uint16(1 << num)

		sudoku.rows[row] |= bit
		sudoku.cols[col] |= bit
		sudoku.boxes[box] |= bit
	}

	return sudoku, nil
}

func readPuzzleFile(path string) ([]byte, error) {
	data, err := os.ReadFile(path)
	if err == nil {
		return data, nil
	}

	fallback := filepath.Join("..", path)
	return os.ReadFile(fallback)
}

func solve(s *Sudoku) bool {
	index := findBestCell(s)
	if index == -1 {
		return true
	}

	row := index / 9
	col := index % 9
	box := (row/3)*3 + (col / 3)
	used := s.rows[row] | s.cols[col] | s.boxes[box]
	available := uint16(0x1FF) &^ used

	for num := 0; num < 9; num++ {
		bit := uint16(1 << num)
		if available&bit == 0 {
			continue
		}

		s.puzzle[index] = byte('1' + num)
		s.rows[row] |= bit
		s.cols[col] |= bit
		s.boxes[box] |= bit

		if solve(s) {
			return true
		}

		s.puzzle[index] = '0'
		s.rows[row] &^= bit
		s.cols[col] &^= bit
		s.boxes[box] &^= bit
	}

	return false
}

func findBestCell(s *Sudoku) int {
	bestIndex := -1
	bestCount := 10

	for i := 0; i < 81; i++ {
		if s.puzzle[i] != '0' {
			continue
		}

		row := i / 9
		col := i % 9
		box := (row/3)*3 + (col / 3)
		used := s.rows[row] | s.cols[col] | s.boxes[box]
		available := uint16(0x1FF) &^ used
		count := bits.OnesCount16(available)

		if count < bestCount {
			bestCount = count
			bestIndex = i
		}
	}

	return bestIndex
}

func printPuzzle(puzzle [82]byte) {
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
