const std = @import("std");
pub fn main() !void {
    var file = try std.fs.cwd().openFile("./listing_0037_single_register_mov", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    const test_file = try std.fs.cwd().createFile("test.asm", .{ .read = true });
    defer test_file.close();
    try test_file.writeAll("bits 16\n\n");

    var buf: [2]u8 = undefined;
    while (try in_stream.read(&buf) > 0) {
        var instr: [3]u8 = undefined;
        std.mem.copyForwards(u8, &instr, switch (buf[0] & 0b111111_00) {
            0b100010_00 => "mov",
            else => unreachable,
        });

        const d: u1 = if ((buf[0] & 0b000000_1_0) > 0) 1 else 0; // d = 0 REG-Field is source operand | d = 1 REG-Field is destination operand
        const w: u1 = if ((buf[0] & 0b0000000_1) > 0) 1 else 0;

        const mod: u2 = switch (buf[1] & 0b11_000000) {
            0b00_000000 => 0b00,
            0b01_000000 => 0b01,
            0b10_000000 => 0b10,
            0b11_000000 => 0b11,
            else => unreachable,
        };

        _ = .{mod};

        var reg: [2]u8 = undefined;
        copy_register_name(buf[1] >> 3, w, &reg);

        var r_m: [2]u8 = undefined;
        copy_register_name(buf[1], w, &r_m);

        std.debug.print("{s} {s}, {s}\n", if (d == 0) .{ instr, r_m, reg } else .{ instr, reg, r_m });

        // mov <dest> <src>
        try test_file.writeAll(if (d == 0)
            instr ++ " " ++ r_m ++ ", " ++ reg ++ "\n"
        else
            instr ++ " " ++ reg ++ ", " ++ r_m ++ "\n");
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
