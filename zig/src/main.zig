const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("sudoku solver (zig)\n", .{});

    // TODO: load a puzzle and call the solver here.
}
