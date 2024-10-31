const std = @import("std");
var i: u8 = 0;
pub fn main() !void {
    var file = try std.fs.cwd().openFile("./listing_0039_more_movs", .{});
    defer file.close();

    const reader = file.reader();
    var buffer: [1024]u8 = [_]u8{undefined} ** 1024;
    const file_size = try reader.readAll(&buffer);
    const bytes = buffer[0..file_size];
    std.debug.print("bytes: {b}\n", .{bytes});

    const test_file = try std.fs.cwd().createFile("test.asm", .{ .read = true });
    defer test_file.close();

    const writer = test_file.writer();
    try writer.print("bits 16\n\n", .{});

    while (i < file_size) {
        if (bytes[i] & 0b111111_00 == 0b100010_00) {
            try mov_register_to_register(bytes, writer); // reg -> reg
        } else if (bytes[i] & 0b1111_0000 == 0b1011_0000) {
            try mov_immediate(bytes, writer); // im -> reg
        } else unreachable;
    }
}

fn mov_immediate(bytes: []u8, writer: std.fs.File.Writer) !void {
    const byte1 = bytes[i];
    const byte2 = bytes[i + 1];
    var byte3: u16 = undefined;

    const w: u1 = if ((byte1 & 0b0000_1_000) > 0) 1 else 0;
    // std.debug.print("w: {any}\n", .{w});
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
    try writer.print("{s} {s}, {d}\n", .{ "mov", reg, data });
}

fn mov_register_to_register(bytes: []u8, writer: std.fs.File.Writer) !void {
    const byte1 = bytes[i];
    const byte2 = bytes[i + 1];

    // const disp_l: u8 = undefined;
    // const disp_h: u16 = undefined;

    const d: u1 = if ((byte1 & 0b000000_1_0) > 0) 1 else 0; // d = 0 REG-Field is source operand | d = 1 REG-Field is destination operand
    const w: u1 = if ((byte1 & 0b0000000_1) > 0) 1 else 0;

    const mod: u2 = switch (byte2 & 0b11_000000) {
        0b00_000000 => 0b00,
        0b01_000000 => 0b01,
        0b10_000000 => 0b10,
        0b11_000000 => 0b11,
        else => unreachable,
    };
    std.debug.print("mod: {b}\n", .{mod});

    var reg: [2]u8 = undefined;
    var r_m: [17]u8 = [_]u8{undefined} ** 17;

    if (mod == 0b11) {
        copy_register_name(byte2 >> 3, w, &reg);
        copy_register_name(byte2, w, r_m[0..2]);
        i += 2;
    } else {
        std.mem.copyForwards(u8, &r_m, switch (byte2 & 0b00_000_111) {
            0b00_000_000 => "bx + si",
            0b00_000_001 => "bx + di",
            0b00_000_010 => "bp + si",
            0b00_000_011 => "bp + di",
            0b00_000_100 => "si",
            0b00_000_101 => "di",
            0b00_000_110 => if (mod == 0b00) "75" else "bp", // keine ahnung gerade disp_h
            0b00_000_111 => "bx",
            else => unreachable,
        });
        std.debug.print("rm: {s}\n", .{r_m});

        // _ = switch (mod) {
        //     0b01 => try std.fmt.bufPrint(&r_m, "[{s} + {d}]\n", .{ r_m, disp_l }),
        //     0b10 => try std.fmt.bufPrint(&r_m, "[{s} + {d}]\n", .{ r_m, (disp_h << 8) | disp_l }),
        //     0b00 => try std.fmt.bufPrint(&r_m, "[{s}]\n", .{r_m}),
        //     else => unreachable,
        // };

        // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        // const allocator = gpa.allocator();

        // r_m = switch (mod) {
        //     0b01 => try std.fmt.allocPrint(allocator, "[{s} + {d}]\n", .{ r_m, disp_l }),
        //     0b10 => try std.fmt.allocPrint(allocator, "[{s} + {d}]\n", .{ r_m, (disp_h << 8) | disp_l }),
        //     0b00 => try std.fmt.allocPrint(allocator, "[{s}]\n", .{r_m}),
        //     else => unreachable,
        // };
        // defer allocator.free();

        switch (mod) {
            0b01 => i += 3,
            0b10 => i += 4,
            0b00 => i += 2,
            else => unreachable,
        }
    }

    if (d == 0) {
        try writer.print("{s} {s}, {s}\n", .{ "mov", r_m, reg });
    } else {
        try writer.print("{s} {s}, {s}\n", .{ "mov", reg, r_m });
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
