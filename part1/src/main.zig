const std = @import("std");
var i: u8 = 0;

const assembly = struct {
    buffer: [1024]u8 = [_]u8{undefined} ** 1024,
    r_m: []const u8 = undefined,
    reg: []const u8 = undefined,
    byte_word: []const u8 = undefined,
    data: ?u16 = null,
    disp_h: u16 = undefined,
    disp_l: u8 = undefined,
    byte_count: u8 = 0,
    mod: u2 = undefined,
    d: u1 = undefined,
    s: u1 = undefined,
    w: u1 = undefined,

    fn set_byte_word(self: *assembly) void {
        self.byte_word = switch (self.w) {
            1 => "word",
            0 => "byte",
        };
    }

    fn set_effective_address_calc(self: *assembly, addr: u8, bytes: []u8) !void {
        switch (addr & 0b00_000_111) {
            0b00_000_000 => self.r_m = "bx + si",
            0b00_000_001 => self.r_m = "bx + di",
            0b00_000_010 => self.r_m = "bp + si",
            0b00_000_011 => self.r_m = "bp + di",
            0b00_000_100 => self.r_m = "si",
            0b00_000_101 => self.r_m = "di",
            0b00_000_110 => if (self.mod == 0b00) {
                const byte4: u16 = bytes[i + 3];
                self.byte_count += 1;
                const value: u16 = (byte4 << 8) | bytes[i + 2];
                self.byte_count += 1;
                self.r_m = try std.fmt.bufPrint(&self.buffer, "{d}", .{value});

                self.set_data(bytes);
            } else {
                self.r_m = "bp";
            },
            0b00_000_111 => self.r_m = "bx",
            else => unreachable,
        }
    }

    fn set_register_name(self: assembly, addr: u8, dest: *[]const u8) void {
        dest.* = switch (addr & 0b00_000_111) {
            0b00_000_000 => if (self.w == 0) "al" else "ax",
            0b00_000_001 => if (self.w == 0) "cl" else "cx",
            0b00_000_010 => if (self.w == 0) "dl" else "dx",
            0b00_000_011 => if (self.w == 0) "bl" else "bx",
            0b00_000_100 => if (self.w == 0) "ah" else "sp",
            0b00_000_101 => if (self.w == 0) "ch" else "bp",
            0b00_000_110 => if (self.w == 0) "dh" else "si",
            0b00_000_111 => if (self.w == 0) "bh" else "di",
            else => unreachable,
        };
    }

    fn set_data(self: *assembly, bytes: []u8) void {
        if (self.w == 1 and self.s == 0) {
            const byte_next = bytes[i + self.byte_count];
            self.byte_count += 1;
            self.data = bytes[i + self.byte_count];
            self.byte_count += 1;
            self.data = (self.data.? << 8) | byte_next;
        } else {
            self.data = bytes[i + self.byte_count];
            self.byte_count += 1;
        }
    }
};
pub fn main() !void {
    var args = std.process.args();
    defer args.deinit();

    _ = args.skip();
    const path: ?[]const u8 = args.next();
    if (path == null) {
        return error.InvalidArgument;
    }

    var file = try std.fs.cwd().openFile(path.?, .{});
    // var file = try std.fs.cwd().openFile("../listing_0041_add_sub_cmp_jnz/listing_41_add_sub_cmp_jnz", .{});
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
            0b011101_00,
            0b011111_00,
            0b011111_10,
            0b011100_10,
            0b011101_10,
            0b011110_10,
            0b011100_00,
            0b011110_00,
            0b011101_01,
            0b011111_01,
            0b011111_11,
            0b011100_11,
            0b011101_11,
            0b011110_11,
            0b011100_01,
            0b011110_01,
            0b111000_10,
            0b111000_01,
            0b111000_00,
            0b111000_11,
            => try jump_pattern(bytes, writer),
            else => {
                std.debug.print("{b}\n", .{bytes[i]});
                unreachable;
            },
        }
    }
    std.debug.assert(i == file_size);
}

fn mov_immediate(bytes: []u8, writer: std.fs.File.Writer) !void {
    var a: assembly = assembly{};
    const byte1 = bytes[i];
    const byte2 = bytes[i + 1];
    a.byte_count = 2;
    var byte3: u16 = undefined;

    a.w = if ((byte1 & 0b0000_1_000) > 0) 1 else 0;
    a.set_register_name(byte1, &a.reg);

    if (a.w == 1) {
        byte3 = bytes[i + 2];
        a.data = (byte3 << 8) | byte2;
        a.byte_count += 1;
    } else {
        a.data = byte2;
    }
    i += a.byte_count;
    try writer.print("{s} {s}, {d}\n", .{ "mov", a.reg, a.data.? });
}

fn pattern_register_to_register(bytes: []u8, writer: std.fs.File.Writer, instr_type: []const u8) !void {
    var a: assembly = assembly{};
    const byte1 = bytes[i];
    const byte2 = bytes[i + 1];
    a.byte_count = 2;

    a.d = if ((byte1 & 0b000000_1_0) > 0) 1 else 0; // d = 0 REG-Field is source operand | d = 1 REG-Field is destination operand
    a.w = if ((byte1 & 0b0000000_1) > 0) 1 else 0;

    a.mod = get_mod_field(byte2);

    a.set_register_name(byte2 >> 3, &a.reg);

    switch (a.mod) {
        0b11 => a.set_register_name(byte2, &a.r_m),
        0b01 => {
            a.disp_l = bytes[i + 2];
            a.byte_count += 1;
            try a.set_effective_address_calc(byte2, bytes);
        },
        0b10 => {
            a.disp_l = bytes[i + 2];
            a.byte_count += 1;
            a.disp_h = bytes[i + 3];
            a.byte_count += 1;
            try a.set_effective_address_calc(byte2, bytes);
        },
        0b00 => try a.set_effective_address_calc(byte2, bytes),
    }

    if (a.d == 0) {
        switch (a.mod) {
            0b01 => try writer.print("{s} [{s} + {d}], {s}\n", .{ instr_type, a.r_m, a.disp_l, a.reg }),
            0b10 => try writer.print("{s} [{s} + {d}], {s}\n", .{ instr_type, a.r_m, ((a.disp_h << 8) | a.disp_l), a.reg }),
            0b00 => try writer.print("{s} [{s}], {s}\n", .{ instr_type, a.r_m, a.reg }),
            0b11 => try writer.print("{s} {s}, {s}\n", .{ instr_type, a.r_m, a.reg }),
        }
    } else {
        switch (a.mod) {
            0b01 => try writer.print("{s} {s}, [{s} + {d}]\n", .{ instr_type, a.reg, a.r_m, a.disp_l }),
            0b10 => try writer.print("{s} {s}, [{s} + {d}]\n", .{ instr_type, a.reg, a.r_m, ((a.disp_h << 8) | a.disp_l) }),
            0b00 => try writer.print("{s} {s}, [{s}]\n", .{ instr_type, a.reg, a.r_m }),
            0b11 => try writer.print("{s} {s}, {s}\n", .{ instr_type, a.reg, a.r_m }),
        }
    }
    i += a.byte_count;
}

fn pattern_immediate_register_memory(bytes: []u8, writer: std.fs.File.Writer) !void {
    const byte1 = bytes[i];
    const byte2 = bytes[i + 1];
    var a: assembly = assembly{
        .s = if ((byte1 & 0b000000_1_0) > 0) 1 else 0,
        .w = if ((byte1 & 0b0000000_1) > 0) 1 else 0,
        .mod = get_mod_field(byte2),
        .byte_count = 2,
    };

    const instr = switch (byte2 & 0b00_111_000) {
        0b00_000_000 => "add",
        0b00_101_000 => "sub",
        0b00_111_000 => "cmp",
        else => unreachable,
    };
    switch (a.mod) {
        0b11 => {
            a.set_register_name(byte2, &a.r_m);
            a.set_data(bytes);
        },
        0b01 => {
            a.disp_l = bytes[i + 2];
            a.byte_count += 1;
            a.set_data(bytes);
            try a.set_effective_address_calc(byte2, bytes);
            a.set_byte_word();
        },
        0b10 => {
            a.disp_l = bytes[i + 2];
            a.disp_h = bytes[i + 3];
            a.byte_count += 2;
            a.set_data(bytes);
            try a.set_effective_address_calc(byte2, bytes);
            a.set_byte_word();
        },
        0b00 => {
            try a.set_effective_address_calc(byte2, bytes);
            a.set_byte_word();
            if (a.w == 1 and a.s == 0) {
                a.data = bytes[i + 3];
                a.byte_count += 1;
                a.data = (a.data.? << 8) | bytes[i + 2];
                a.byte_count += 1;
            } else {
                if (a.data == null) {
                    a.data = bytes[i + 2];
                    a.byte_count += 1;
                }
            }
        },
    }

    switch (a.mod) {
        0b01 => try writer.print("{s} {s} [{s} + {d}], {d}\n", .{ instr, a.byte_word, a.r_m, a.disp_l, a.data.? }),
        0b10 => try writer.print("{s} {s} [{s} + {d}], {d}\n", .{ instr, a.byte_word, a.r_m, ((a.disp_h << 8) | a.disp_l), a.data.? }),
        0b00 => try writer.print("{s} {s} [{s}], {d}\n", .{ instr, a.byte_word, a.r_m, a.data.? }),
        0b11 => try writer.print("{s} {s}, {d}\n", .{ instr, a.r_m, a.data.? }),
    }
    i += a.byte_count;
}

fn pattern_immediate_from_accumalator(bytes: []u8, writer: std.fs.File.Writer, instr_type: []const u8) !void {
    const byte1 = bytes[i];
    const byte2 = bytes[i + 1];
    var byte3: u16 = undefined;
    var a = assembly{
        .w = if ((byte1 & 0b0000000_1) > 0) 1 else 0,
    };

    if (a.w == 1) {
        a.reg = "ax";
        byte3 = bytes[i + 2];
        a.data = (byte3 << 8) | byte2;
        i += 3;
    } else {
        a.reg = "al";
        a.data = byte2;
        i += 2;
    }
    try writer.print("{s} {s}, {d}\n", .{ instr_type, a.reg, a.data.? });
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

fn jump_pattern(bytes: []u8, writer: std.fs.File.Writer) !void {
    const ip_inc8: u8 = bytes[i + 1];

    const opcode = switch (bytes[i] & 0b11111111) {
        0b01110100 => "je",
        0b01111100 => "jl",
        0b01111110 => "jle",
        0b01110010 => "jb",
        0b01110110 => "jbe",
        0b01111010 => "jp",
        0b01110000 => "jo",
        0b01111000 => "js",
        0b01110101 => "jne",
        0b01111101 => "jnl",
        0b01111111 => "jg",
        0b01110011 => "jnb",
        0b01110111 => "ja",
        0b01111011 => "jnp",
        0b01110001 => "jno",
        0b01111001 => "jns",
        0b11100010 => "loop",
        0b11100001 => "loopz",
        0b11100000 => "loopnz",
        0b11100011 => "jcxz",
        else => unreachable,
    };

    try writer.print("{s} {d}\n", .{ opcode, ip_inc8 });
    i += 2;
}
