const std = @import("std");
pub fn main() !void {
    var file = try std.fs.cwd().openFile("./listing_0039_more_movs", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    const test_file = try std.fs.cwd().createFile("test.asm", .{ .read = true });
    defer test_file.close();

    const writer = test_file.writer();
    try writer.print("bits 16\n\n", .{});

    var buf: [2]u8 = undefined;
    while (try in_stream.read(&buf) > 0) {
        var instr: [3]u8 = undefined;
        std.mem.copyForwards(u8, &instr, switch (buf[0] & 0b1111_0000) {
            0b1011_0000 => "mov",
            else => unreachable,
        });

        const w: u1 = if ((buf[0] & 0b0000_1_000) > 0) 1 else 0;

        var reg: [2]u8 = undefined;
        copy_register_name(buf[0], w, &reg);

        std.debug.print("{s} {s}, {d}\n", .{ instr, reg, buf[1] });

        const data = [1]u8{@bitCast(buf[1])};
        std.debug.print("{any}\n", .{data});
        try writer.print("{s} {s}, {d}\n", .{ instr, reg, buf[1] });
    }
}

fn copy_register_name(addr: u8, w: u1, dest: *[2]u8) void {
    if (w == 0) {
        std.mem.copyForwards(u8, &dest.*, switch (addr & 0b00_000_111) {
            0b00_000_000 => "al",
            0b00_000_001 => "cl",
            0b00_000_010 => "dl",
            0b00_000_011 => "bl",
            0b00_000_100 => "ah",
            0b00_000_101 => "ch",
            0b00_000_110 => "dh",
            0b00_000_111 => "bh",
            else => unreachable,
        });
    } else {
        std.mem.copyForwards(u8, &dest.*, switch (addr & 0b00_000_111) {
            0b00_000_000 => "ax",
            0b00_000_001 => "cx",
            0b00_000_010 => "dx",
            0b00_000_011 => "bx",
            0b00_000_100 => "sp",
            0b00_000_101 => "bp",
            0b00_000_110 => "si",
            0b00_000_111 => "di",
            else => unreachable,
        });
    }
}
