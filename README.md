# sudoku_solvers

## Algorithm

I want to keep the core algorithm simple and repeatable. The easiest way to write a sudoku solver is a recursive algorithm that, for each empty square, selects a legal number and continues to the next empty square. Of course, it is probably not the case that a given number that currently appears legal given our limited information will actually be a part of the solution. When the recursive chain hits a dead end, it'll 'return false' back upwards to try a different legal number in that square, and continue again from there.
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

#### "get available digits for that cell"

A slightly smarter way to approach this is to use bitmasking. We can represent the digits 1 through 9 as individual bits, then use the row, column, and box masks to quickly determine which digits are still valid.

Instead of repeatedly scanning arrays for each row, column, and box every time we check validity, we can represent the board state in a compact form that can be queried and updated in O(1) time.

For example, if a row already contains 1, 4, and 7, its mask could be:

```text
001001001
```

To find the legal digits for a cell, we combine the row, column, and box masks, then invert the result:

```text
FULL_MASK = 111111111

used = row_mask[r] | col_mask[c] | box_mask[b]
available = FULL_MASK & ~used
```

Any bit set in `available` represents a digit we are allowed to place.
```
