const std = @import("std");

const puzzle_len = 81;
const puzzle_buf_len = puzzle_len + 1;

const Sudoku = struct {
    puzzle: [puzzle_buf_len]u8 = [_]u8{0} ** puzzle_buf_len,
    rows: [9]u16 = [_]u16{0} ** 9,
    cols: [9]u16 = [_]u16{0} ** 9,
    boxes: [9]u16 = [_]u16{0} ** 9,
};

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&stdout_buffer);
    defer stdout.interface.flush() catch {};

    var stderr_buffer: [1024]u8 = undefined;
    var stderr = std.fs.File.stderr().writer(&stderr_buffer);
    defer stderr.interface.flush() catch {};

    try stdout.interface.print("sudoku solver (zig)\n", .{});

    /////////////////
    // LOAD PUZZLE //
    /////////////////

    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    // check to see if args
    if (args.len < 2) {
        try stderr.interface.print("Usage: {s} <easy|hard> [repeat_count]\n", .{args[0]});
        std.process.exit(1);
    }

    // figure out how many times to repeat (for benchmarking)
    var repeat_count: usize = 1;
    if (args.len >= 3) {
        repeat_count = std.fmt.parseInt(usize, args[2], 10) catch {
            try stderr.interface.print("repeat_count must be at least 1\n", .{});
            std.process.exit(1);
        };
        if (repeat_count < 1) {
            try stderr.interface.print("repeat_count must be at least 1\n", .{});
            std.process.exit(1);
        }
    }

    // choose puzzle
    const puzzle_file = blk: {
        if (args[1][0] == 'e') break :blk "../puzzles/easy.txt";
        if (args[1][0] == 'h') break :blk "puzzles/hard.txt";

        try stderr.interface.print("Invalid option. Use 'easy' or 'hard'\n", .{});
        std.process.exit(1);
    };

    // open file
    var file = std.fs.cwd().openFile(puzzle_file, .{}) catch {
        try stderr.interface.print("Error opening file\n", .{});
        std.process.exit(1);
    };
    defer file.close();

    // read file into one big string
    var sudoku = Sudoku{};
    const bytes_read = file.readAll(sudoku.puzzle[0..]) catch {
        try stderr.interface.print("Error reading file\n", .{});
        std.process.exit(1);
    };

    if (bytes_read == 0) {
        try stderr.interface.print("Error reading file\n", .{});
        std.process.exit(1);
    }

    const original_puzzle = sudoku.puzzle;

    // parse puzzle and fill in bits
    // look through each character in the puzzle string.
    for (0..puzzle_len) |i| {
        const c = sudoku.puzzle[i];
        if (c >= '1' and c <= '9') {
            // figure out which row, column, and box this number belongs to.
            const num = c - '1'; // 0-8 instead of 1-9
            const row = i / 9;
            const col = i % 9;
            const box = (row / 3) * 3 + (col / 3);
            const bit: u16 = @as(u16, 1) << @intCast(num);
            sudoku.rows[row] |= bit;
            sudoku.cols[col] |= bit;
            sudoku.boxes[box] |= bit;
        }
    }

    //////////////////
    // SOLVE PUZZLE //
    //////////////////

    var solved = false;
    var elapsed_ms: f64 = 0.0;

    if (repeat_count == 1) {
        var timer = try std.time.Timer.start();
        solved = solve(&sudoku);
        elapsed_ms = @as(f64, @floatFromInt(timer.read())) / @as(f64, std.time.ns_per_ms);
    } else {
        var timer = try std.time.Timer.start();
        var run: usize = 0;
        while (run < repeat_count) : (run += 1) {
            var benchmark = sudoku;
            solved = solve(&benchmark);
            if (!solved) break;
        }
        elapsed_ms = @as(f64, @floatFromInt(timer.read())) / @as(f64, std.time.ns_per_ms);
    }

    if (!solved) {
        try stderr.interface.print("No solution found\n", .{});
    } else {
        if (repeat_count == 1) {
            try stdout.interface.print("Initial puzzle:\n", .{});
            try print_puzzle(&stdout, original_puzzle);
            try stdout.interface.print("\nSolved puzzle:\n", .{});
            try print_puzzle(&stdout, sudoku.puzzle);
            try stdout.interface.print("\nSolved in {d:.3} ms\n", .{elapsed_ms});
        } else { // if benchmarking, skip the pretty print and just show the timing results
            try stdout.interface.print("Solved {d} runs in {d:.3} s\n", .{ repeat_count, elapsed_ms / 1000.0 });
            try stdout.interface.print("Average: {d:.6} ms per run\n", .{elapsed_ms / @as(f64, @floatFromInt(repeat_count))});
        }
    }
}

fn solve(sudoku: *Sudoku) bool {
    const index = find_best_cell(sudoku);
    if (index == -1) {
        // no empty cells, puzzle solved
        return true;
    }

    const cell: usize = @intCast(index);
    const row = cell / 9;
    const col = cell % 9;
    const box = (row / 3) * 3 + (col / 3);
    const used = sudoku.rows[row] | sudoku.cols[col] | sudoku.boxes[box];
    const available: u16 = 0x1FF & ~used; // bits for digits 1-9

    var num: u8 = 0;
    while (num < 9) : (num += 1) {
        const bit: u16 = @as(u16, 1) << @intCast(num);
        if ((available & bit) != 0) { // if this digit is available
            // place the digit
            const c = '1' + num;
            sudoku.puzzle[cell] = c;
            sudoku.rows[row] |= bit;
            sudoku.cols[col] |= bit;
            sudoku.boxes[box] |= bit;

            // recursively solve the rest of the puzzle
            if (solve(sudoku)) {
                return true; // solution found
            }

            // backtrack
            sudoku.puzzle[cell] = '0';
            sudoku.rows[row] &= ~bit;
            sudoku.cols[col] &= ~bit;
            sudoku.boxes[box] &= ~bit;
        }
    }

    return false; // no solution found
}

fn find_best_cell(sudoku: *const Sudoku) i32 {
    // loop through all cells and find the one with the fewest possibilities
    var best_index: i32 = -1;
    var best_count: u16 = 10; // more than the max possible (9)

    for (0..puzzle_len) |i| {
        if (sudoku.puzzle[i] == '0') { // if cell is empty
            const row = i / 9;
            const col = i % 9;
            const box = (row / 3) * 3 + (col / 3);
            const used = sudoku.rows[row] | sudoku.cols[col] | sudoku.boxes[box];
            const available: u16 = 0x1FF & ~used;
            const count = @popCount(available); // count legal digits
            if (count < best_count) {
                best_count = count;
                best_index = @intCast(i);
            }
        }
    }

    return best_index;
}

fn print_puzzle(writer: *std.fs.File.Writer, puzzle: [puzzle_buf_len]u8) !void {
    for (0..puzzle_len) |i| {
        var c = puzzle[i];
        if (c == '0') c = '-';

        try writer.interface.print("{c}", .{c});

        if (i % 9 != 8) {
            try writer.interface.print(" ", .{});
        }

        if (i % 9 == 2 or i % 9 == 5) {
            try writer.interface.print("| ", .{});
        }

        if (i % 9 == 8) {
            try writer.interface.print("\n", .{});
            if (i == 26 or i == 53) {
                try writer.interface.print("------+-------+------\n", .{});
            }
        }
    }
}
