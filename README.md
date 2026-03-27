# sudoku_solvers

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

Sudoku is an example of what a mathematician would call an 'exact cover problem'. Many papers have been written on this subject. A very clever (but much more complex) way to solve a problem like this is to use Knuth's "Algorithm X", and implement it using the "Dancing Links" technique.

It's worth noting that a more resource-efficient implementation is possible. If I were building this for a production setting where raw performance mattered, I'd probably revisit those papers and break out the doubly linked lists.

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

```c
NINE_BIT_MASK = 0b111111111
used = row_mask[r] | col_mask[c] | box_mask[b]
available = NINE_BIT_MASK & ~used
```

