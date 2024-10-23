const std = @import("std");
pub fn main() !void {
    var file = try std.fs.cwd().openFile("./listing_0039_more_movs", .{});
    defer file.close();

    const reader = file.reader();
    var buffer: [1024]u8 = [_]u8{undefined} ** 1024;
    const file_size = try reader.readAll(&buffer);
    const bytes = buffer[0..file_size];
    std.debug.print("bytes : {b}\n", .{bytes});

    const test_file = try std.fs.cwd().createFile("test.asm", .{ .read = true });
    defer test_file.close();

    const writer = test_file.writer();
    try writer.print("bits 16\n\n", .{});

    var i: u8 = 0;
    while (i < file_size) {
        const byte1 = bytes[i];
        const byte2 = bytes[i + 1];
        var byte3: u16 = undefined;

        std.debug.print("buffer: {b}\n", .{bytes[i]});
        var instr: [3]u8 = undefined;

        std.mem.copyForwards(u8, &instr, switch (byte1 & 0b1111_0000) {
            0b1011_0000 => "mov",
            else => unreachable,
        });

        const w: u1 = if ((byte1 & 0b0000_1_000) > 0) 1 else 0;
        std.debug.print("w: {any}\n", .{w});
        var reg: [2]u8 = undefined;
        copy_register_name(byte1, w, &reg);

        var data: u16 = undefined;

        if (w == 1) {
            byte3 = bytes[i + 2];
            data = (byte3 << 8) | byte2;
            i += 3;
        } else {
            data = byte2;
            i += 2;
        }
        std.debug.print("{s} {s}, {d}\n", .{ instr, reg, data });
        try writer.print("{s} {s}, {d}\n", .{ instr, reg, data });
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
