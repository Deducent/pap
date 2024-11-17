const std = @import("std");
var i: u8 = 0;
pub fn main() !void {
    // var args = std.process.args();
    // defer args.deinit();
    //
    // _ = args.skip();
    // const path: ?[]const u8 = args.next();
    // if (path == null) {
    //     return error.InvalidArgument;
    // }
    //
    // var file = try std.fs.cwd().openFile(path.?, .{});
    var file = try std.fs.cwd().openFile("../listing_0041_add_sub_cmp_jnz/listing_41_add_sub_cmp_jnz", .{});
    defer file.close();

    const reader = file.reader();
    var buffer: [1024]u8 = [_]u8{undefined} ** 1024;
    const file_size = try reader.readAll(&buffer);
    const bytes = buffer[0..file_size];

    const test_file = try std.fs.cwd().createFile("test.asm", .{ .read = true });
    defer test_file.close();

    const writer = test_file.writer();
    try writer.print("bits 16\n\n", .{});

    std.debug.print("bytes: {b}\n", .{bytes});
    while (i < file_size) {
        switch (bytes[i] & 0b111111_00) {
            0b1011_0000 => try mov_immediate(bytes, writer), // im -> reg
            0b100010_00 => try pattern_register_to_register(bytes, writer, "mov"), // reg -> reg
            0b000000_00 => try pattern_register_to_register(bytes, writer, "add"), // reg -> reg
            0b001010_00 => try pattern_register_to_register(bytes, writer, "sub"), // reg -> reg
            0b001110_00 => try pattern_register_to_register(bytes, writer, "cmp"), // reg -> reg
            0b100000_00 => try pattern_immediate_register_memory(bytes, writer), // reg -> memory
            0b000001_00 => try pattern_immediate_from_accumalator(bytes, writer, "add"),
            0b001011_00 => try pattern_immediate_from_accumalator(bytes, writer, "sub"),
            0b001111_00 => try pattern_immediate_from_accumalator(bytes, writer, "cmp"),
            else => unreachable,
        }
    }
    std.debug.assert(i == file_size);
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
    std.debug.print("{s} {s}, {d}\n", .{ "mov", reg, data });
    try writer.print("{s} {s}, {d}\n", .{ "mov", reg, data });
}

fn pattern_register_to_register(bytes: []u8, writer: std.fs.File.Writer, instr_type: []const u8) !void {
    const byte1 = bytes[i];
    const byte2 = bytes[i + 1];

    var disp_l: u8 = undefined;
    var disp_h: u16 = undefined;

    const d: u1 = if ((byte1 & 0b000000_1_0) > 0) 1 else 0; // d = 0 REG-Field is source operand | d = 1 REG-Field is destination operand
    const w: u1 = if ((byte1 & 0b0000000_1) > 0) 1 else 0;

    const mod: u2 = get_mod_field(byte2);

    var reg: [2]u8 = undefined;
    var r_m: [7]u8 = [_]u8{undefined} ** 7;

    copy_register_name(byte2 >> 3, w, &reg);

    if (mod == 0b11) {
        copy_register_name(byte2, w, r_m[0..2]);
        i += 2;
    } else {
        if (bytes.len > (i + 2)) disp_l = bytes[i + 2];
        if (bytes.len > (i + 3)) disp_h = bytes[i + 3];

        copy_effective_address_calc(byte2, &r_m, mod);

        switch (mod) {
            0b01 => i += 3,
            0b10 => i += 4,
            0b00 => i += 2,
            else => unreachable,
        }
    }
    const rm = std.mem.trim(u8, &r_m, &[_]u8{undefined});

    if (d == 0) {
        switch (mod) {
            0b01 => std.debug.print("{s} [{s} + {d}], {s}\n", .{ instr_type, rm, disp_l, reg }),
            0b10 => std.debug.print("{s} [{s} + {d}], {s}\n", .{ instr_type, rm, ((disp_h << 8) | disp_l), reg }),
            0b00 => std.debug.print("{s} [{s}], {s}\n", .{ instr_type, rm, reg }),
            0b11 => std.debug.print("{s} {s}, {s}\n", .{ instr_type, rm, reg }),
        }
    } else {
        switch (mod) {
            0b01 => std.debug.print("{s} {s}, [{s} + {d}]\n", .{ instr_type, reg, rm, disp_l }),
            0b10 => std.debug.print("{s} {s}, [{s} + {d}]\n", .{ instr_type, reg, rm, ((disp_h << 8) | disp_l) }),
            0b00 => std.debug.print("{s} {s}, [{s}]\n", .{ instr_type, reg, rm }),
            0b11 => std.debug.print("{s} {s}, {s}\n", .{ instr_type, reg, rm }),
        }
    }
    if (d == 0) {
        switch (mod) {
            0b01 => try writer.print("{s} [{s} + {d}], {s}\n", .{ instr_type, rm, disp_l, reg }),
            0b10 => try writer.print("{s} [{s} + {d}], {s}\n", .{ instr_type, rm, ((disp_h << 8) | disp_l), reg }),
            0b00 => try writer.print("{s} [{s}], {s}\n", .{ instr_type, rm, reg }),
            0b11 => try writer.print("{s} {s}, {s}\n", .{ instr_type, rm, reg }),
        }
    } else {
        switch (mod) {
            0b01 => try writer.print("{s} {s}, [{s} + {d}]\n", .{ instr_type, reg, rm, disp_l }),
            0b10 => try writer.print("{s} {s}, [{s} + {d}]\n", .{ instr_type, reg, rm, ((disp_h << 8) | disp_l) }),
            0b00 => try writer.print("{s} {s}, [{s}]\n", .{ instr_type, reg, rm }),
            0b11 => try writer.print("{s} {s}, {s}\n", .{ instr_type, reg, rm }),
        }
    }
}

fn pattern_immediate_register_memory(bytes: []u8, writer: std.fs.File.Writer) !void {
    const byte1 = bytes[i];
    const byte2 = bytes[i + 1];
    const s: u1 = if ((byte1 & 0b000000_1_0) > 0) 1 else 0;
    const w: u1 = if ((byte1 & 0b0000000_1) > 0) 1 else 0;
    var disp_l: u8 = undefined;
    var disp_h: u16 = undefined;
    var data: u16 = undefined;
    var byte_word: [4]u8 = [_]u8{0} ** 4;

    var r_m: [7]u8 = [_]u8{undefined} ** 7;

    const mod: u2 = get_mod_field(byte2);

    const instr = switch (byte2 & 0b00_111_000) {
        0b00_000_000 => "add",
        0b00_101_000 => "sub",
        0b00_111_000 => "cmp",
        else => unreachable,
    };
    switch (mod) {
        0b11 => {
            copy_register_name(byte2, w, r_m[0..2]);
            if (w == 1 and s == 0) {
                data = (bytes[i + 2] << 7) | bytes[i + 3];
                i += 4;
            } else {
                data = bytes[i + 2];
                i += 3;
            }
        },
        0b01 => {
            disp_l = bytes[i + 2];
            if (w == 1 and s == 0) {
                data = (bytes[i + 3] << 7) | bytes[i + 4];
                i += 5;
            } else {
                data = bytes[i + 3];
                i += 4;
            }
            copy_effective_address_calc(byte2, &r_m, mod);
            std.mem.copyForwards(u8, &byte_word, switch (w) {
                1 => "word",
                0 => "byte",
            });
        },
        0b10 => {
            disp_l = bytes[i + 2];
            disp_h = bytes[i + 3];
            if (w == 1 and s == 0) {
                data = (bytes[i + 4] << 7) | bytes[i + 5];
                i += 6;
            } else {
                data = bytes[i + 4];
                i += 5;
            }
            copy_effective_address_calc(byte2, &r_m, mod);
            std.mem.copyForwards(u8, &byte_word, switch (w) {
                1 => "word",
                0 => "byte",
            });
        },
        0b00 => {
            std.mem.copyForwards(u8, &r_m, switch (byte2 & 0b00_000_111) {
                0b00_000_000 => "bx + si",
                0b00_000_001 => "bx + di",
                0b00_000_010 => "bp + si",
                0b00_000_011 => "bp + di",
                0b00_000_100 => "si",
                0b00_000_101 => "di",
                0b00_000_110 => if (mod == 0b00) {
                    try std.fmt.bufPrint(&r_m, "{d}", (bytes[i + 2] << 7) | bytes[i + 3]);
                } else "bp", // FIXME: What is direct address
                0b00_000_111 => "bx",
                else => unreachable,
            });
            // copy_effective_address_calc(byte2, &r_m, mod);
            std.mem.copyForwards(u8, &byte_word, switch (w) {
                1 => "word",
                0 => "byte",
            });
            if (w == 1 and s == 0) {
                data = (bytes[i + 2] << 7) | bytes[i + 3];
                i += 4;
            } else {
                data = bytes[i + 2];
                i += 3;
            }
        },
    }
    const rm = std.mem.trim(u8, &r_m, &[_]u8{undefined});

    switch (mod) {
        0b01 => std.debug.print("{s} {s} [{s} + {d}], {d}\n", .{ instr, byte_word, rm, disp_l, data }),
        0b10 => std.debug.print("{s} {s} [{s} + {d}], {d}\n", .{ instr, byte_word, rm, ((disp_h << 8) | disp_l), data }),
        0b00 => std.debug.print("{s} {s} [{s}], {d}\n", .{ instr, byte_word, rm, data }),
        0b11 => std.debug.print("{s} {s}, {d}\n", .{ instr, rm, data }),
    }
    switch (mod) {
        0b01 => try writer.print("{s} {s} [{s} + {d}], {d}\n", .{ instr, byte_word, rm, disp_l, data }),
        0b10 => try writer.print("{s} {s} [{s} + {d}], {d}\n", .{ instr, byte_word, rm, ((disp_h << 8) | disp_l), data }),
        0b00 => try writer.print("{s} {s} [{s}], {d}\n", .{ instr, byte_word, rm, data }),
        0b11 => try writer.print("{s} {s}, {d}\n", .{ instr, rm, data }),
    }
}

fn pattern_immediate_from_accumalator(bytes: []u8, writer: std.fs.File.Writer, instr_type: []const u8) !void {
    const byte1 = bytes[i];
    const byte2 = bytes[i + 1];
    var byte3: u16 = undefined;

    const w: u1 = if ((byte1 & 0b0000000_1) > 0) 1 else 0;

    var data: u16 = undefined;

    var reg: []const u8 = undefined;

    if (w == 1) {
        reg = "ax";
        byte3 = bytes[i + 2];
        data = (byte3 << 8) | byte2;
        i += 3;
    } else {
        reg = "al";
        data = byte2;
        i += 2;
    }
    std.debug.print("{s} {s}, {d}\n", .{ instr_type, reg, data });
    try writer.print("{s} {s}, {d}\n", .{ instr_type, reg, data });
}

fn copy_register_name(addr: u8, w: u1, dest: *[2]u8) void {
    std.mem.copyForwards(u8, &dest.*, switch (addr & 0b00_000_111) {
        0b00_000_000 => if (w == 0) "al" else "ax",
        0b00_000_001 => if (w == 0) "cl" else "cx",
        0b00_000_010 => if (w == 0) "dl" else "dx",
        0b00_000_011 => if (w == 0) "bl" else "bx",
        0b00_000_100 => if (w == 0) "ah" else "sp",
        0b00_000_101 => if (w == 0) "ch" else "bp",
        0b00_000_110 => if (w == 0) "dh" else "si",
        0b00_000_111 => if (w == 0) "bh" else "di",
        else => unreachable,
    });
}

fn copy_effective_address_calc(addr: u8, dest: *[7]u8, mod: u2) void {
    std.mem.copyForwards(u8, &dest.*, switch (addr & 0b00_000_111) {
        0b00_000_000 => "bx + si",
        0b00_000_001 => "bx + di",
        0b00_000_010 => "bp + si",
        0b00_000_011 => "bp + di",
        0b00_000_100 => "si",
        0b00_000_101 => "di",
        0b00_000_110 => if (mod == 0b00) "75" else "bp", // FIXME: What is direct address
        0b00_000_111 => "bx",
        else => unreachable,
    });
}

fn get_mod_field(byte: u8) u2 {
    return switch (byte & 0b11_000000) {
        0b00_000000 => 0b00,
        0b01_000000 => 0b01,
        0b10_000000 => 0b10,
        0b11_000000 => 0b11,
        else => unreachable,
    };
}
