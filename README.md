# sudoku_solvers

## C Alternatives

The main purpose of this project is to compare several different languages that are often billed as alternatives to C. 

I first learned to program in C and C++, so I have a certain fondness for the language that might make it hard for me to be objective about its rough edges. I want to see how the alternatives stack up in terms of both ease of development and performance.

The languages I want to compare are:
- C
- Rust
- Go
- Zig
- Odin

## Puzzle Format

Puzzle files live in the `puzzles/` directory. Each puzzle is stored as a single line of 81 characters, using the digits 1 through 9 for filled cells and `0` for empty cells.

For example:

```text
530070000600195000098000060800060003400803001700020006060000280000419005000080079
```

Corresponds to:
```text
5 3 - | 7 - - | - - -
6 - - | 1 9 5 | - - -
- 9 8 | - - - | - 6 -
------+-------+------
8 - - | - 6 - | - - 3
4 - - | 8 - 3 | - - 1
7 - - | - 2 - | - - 6
------+-------+------
- 6 - | - - - | 2 8 -
- - - | 4 1 9 | - - 5
- - - | - 8 - | - 7 9
```

## Algorithm

I want to keep the core algorithm simple and repeatable. The easiest way to write a sudoku solver is a recursive algorithm that, for each empty square, selects a legal number and continues to the next empty square. Of course, a number can be legal in the current position and still not actually be part of the final solution. When the recursive chain hits a dead end, it'll 'return false' back upwards to try a different legal number in that square, and continue again from there.
This is basically just a special depth-first search

```text
solve():
    find an empty cell
    if none exists:
        return true

    get available digits for that cell

    for each available digit:
        place digit
        if solve():
            return true
        undo digit

    return false
```

### Notes on the Algorithm

#### Algorithm X and Dancing Links

I want to briefly acknowledge that this is not actually the best way to solve a Sudoku puzzle.

Sudoku is an example of what a mathematician would call an 'exact cover problem'. Many papers have been written on this subject. A very clever (but much more complex) way to solve a problem like this is to use Knuth's "Algorithm X", and implement it using the "Dancing Links" technique. This would involve using doubly linked list to represent all of the constraints.

If I were building this for a production setting where raw performance mattered, I'd try to do it this way. For the sake of the simplicity of this project though, I'll stick to the more straightforward approach.

#### "find an empty cell"

The most naive way to do this would just be to traverse the board from top to bottom, left to right, looking for empty cells. I want to be a little smarter than that. A good heuristic is to instead find the cell with the *fewest legal digits* allowed. Choosing that cell first will reduce the amount of backtracking we have to do.

The easiest way to implement this is to just scan the board and count the legal digits for each empty cell, keeping track of the one with the fewest. It adds the overhead of scanning the board on each recursive call, but since the size of the board is fixed at 9x9, and the potential time saved by reducing backtracking is much greater, it's almost certainly worth it in practice.

#### "get available digits for that cell"

A slightly smarter way to approach this is to use bitmasking.

Instead of repeatedly scanning the board every time we want to check legality, we can maintain a collection of integers, where each bit represents whether a digit is present in that row, column, or box. This allows us to quickly compute the legal digits for a cell using bitwise operations.

For example, if a row already contains 1, 4, and 7, its mask could be:

```text
001001001
```

To find the legal digits for a cell, we do an OR operation on the row, column, and box masks, then invert the result and keep only the lowest 9 bits:

```text
NINE_BIT_MASK = 0x1FF
used = row_mask[r] | col_mask[c] | box_mask[b]
available = NINE_BIT_MASK & ~used
```

# Speed Results

```text
Sudoku benchmark
Puzzle: easy
Repeat count: 1000000

impl   status                               avg ms/run  puzzles/sec     wall sec
----------------------------------------------------------------------------------
c      ok                                     0.004304    232342.01        4.304
zig    ok                                     0.004626    216169.48        4.627
odin   ok                                     0.004776    209380.23        4.777
go     ok                                     0.005186    192826.84        5.187
rust   ok                                     0.006161    162311.31        6.162
```

```text
Sudoku benchmark
Puzzle: hard
Repeat count: 1000000

impl   status                               avg ms/run  puzzles/sec     wall sec
----------------------------------------------------------------------------------
c      ok                                     0.036103     27698.53       36.104
zig    ok                                     0.042886     23317.63       42.886
odin   ok                                     0.043144     23178.19       43.146
go     ok                                     0.043328     23079.76       43.330
rust   ok                                     0.055663     17965.26       55.664
```
