const std = @import("std");
var i: u8 = 0;

const source_operand = union(enum) {
    reg: []const u8,
    memory: []const u8,
    data: u16,
};

fn get_low(value: u16) u8 {
    return @truncate(value & 0b1111_1111);
}

fn get_high(value: u16) u8 {
    return @truncate((value & 0b1111_1111_0000_0000) >> 8);
}

fn set_low(old_value: *u16, value: u16) void {
    old_value.* &= 0b11111111_00000000;
    const low_part: u16 = value & 0b00000000_11111111;
    old_value.* |= low_part;
}

fn set_high(old_val: *u16, value: u16) void {
    old_val.* &= 0b00000000_11111111;
    const high_part: u16 = value & 0b11111111_00000000;
    old_val.* |= high_part;
}

const cpu_regs = struct {
    map: std.StringHashMap(u16),

    fn get(self: *cpu_regs, key: []const u8) u16 {
        const parent_register = switch (key[0]) {
            'a' => "ax",
            'b' => "bx",
            'c' => "cx",
            'd' => "dx",
            else => "",
        };
        if (key[1] == 'l') {
            return get_low(self.map.get(parent_register).?);
        } else if (key[1] == 'h') {
            return get_high(self.map.get(parent_register).?);
        }
        return self.map.get(key).?;
    }

    fn put(self: *cpu_regs, key: []const u8, value: u16) !void {
        const parent_register = switch (key[0]) {
            'a' => "ax",
            'b' => "bx",
            'c' => "cx",
            'd' => "dx",
            else => "",
        };

        if (key[1] == 'l') {
            var previous_value: u16 = self.map.get(parent_register).?;
            set_low(&previous_value, value);
            try self.map.put(parent_register, previous_value);
        } else if (key[1] == 'h') {
            var previous_value: u16 = self.map.get(parent_register).?;
            set_high(&previous_value, value);
            try self.map.put(parent_register, previous_value);
        }
        try self.map.put(key, value);
    }
};

const assembly = struct {
    buffer: [1024]u8 = [_]u8{undefined} ** 1024,
    full_instr: struct {
        opcode: []const u8,
        src_operand: source_operand,
        dest_operand: []const u8,
    } = .{
        .opcode = undefined,
        .dest_operand = undefined,
        .src_operand = undefined,
    },
    flags: u16 = 0,
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

    fn set_zeroflag(self: *assembly) void {
        // 0000000000000000
        // 0000000001000000 or
        // 0000000001000000
        self.flags |= 0b1_000_000;
    }

    fn is_set_zeroflag(self: *assembly) bool {
        // 0000000000000000
        // 0000000001000000 or
        // 0000000001000000
        return (self.flags & 0b1_000_000) > 0;
    }

    fn unset_zeroflag(self: *assembly) void {
        // 0000100011000000
        // 1111111110111111 and
        // 0000100010000000
        self.flags &= 0b1111_1111_1011_1111;
    }

    fn set_signflag(self: *assembly) void {
        self.flags |= 0b10_000_000;
    }

    fn is_set_signflag(self: *assembly) bool {
        return (self.flags & 0b10_000_000) > 0;
    }

    fn unset_signflag(self: *assembly) void {
        self.flags &= 0b1111_1111_0111_1111;
    }

    fn clear(self: *assembly) void {
        self.buffer = [_]u8{undefined} ** 1024;
        self.r_m = undefined;
        self.reg = undefined;
        self.byte_word = undefined;
        self.data = null;
        self.disp_h = undefined;
        self.disp_l = undefined;
        self.byte_count = 0;
        self.mod = undefined;
        self.d = undefined;
        self.s = undefined;
        self.w = undefined;
    }
};

var a: assembly = assembly{};
pub fn main() !void {
    var args = std.process.args();
    defer args.deinit();

    _ = args.skip();
    const path: ?[]const u8 = args.next();

    var file = try std.fs.cwd().openFile(path.?, .{});
    // var file = try std.fs.cwd().openFile("../listing_0046_add_sub_cmp/listing_0046_add_sub_cmp", .{}); //INFO: for debugging
    defer file.close();

    const reader = file.reader();
    var buffer: [1024]u8 = [_]u8{undefined} ** 1024;
    const file_size = try reader.readAll(&buffer);
    const bytes = buffer[0..file_size];

    const test_file = try std.fs.cwd().createFile("test2.asm", .{ .read = true });
    defer test_file.close();

    const writer = test_file.writer();
    try writer.print("bits 16\n\n", .{});

    std.debug.print("bytes: {b}\n", .{bytes});

    const allocator = std.heap.page_allocator;
    var map = std.StringHashMap(u16).init(allocator);
    defer map.deinit();
    try set_hash_map(&map);

    var cpu_register: cpu_regs = cpu_regs{ .map = map };
    print_hash_map(cpu_register.map);
    while (i < file_size) {
        switch (bytes[i] & 0b111111_00) {
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
                if (bytes[i] & 0b1111_0000 == 0b1011_0000) {
                    try mov_immediate(bytes, writer); // im -> reg
                } else {
                    std.debug.print("{b}\n", .{bytes[i]});
                    std.debug.print("{b}\n", .{bytes[i] & 0b111111_00});
                    unreachable;
                }
            },
        }
        try run_asm(&cpu_register);
        a.clear();
    }
    std.debug.assert(i == file_size);
    print_hash_map(cpu_register.map);
}

fn set_hash_map(map: *std.StringHashMap(u16)) !void {
    try map.put("ax", 0);
    try map.put("bx", 0);
    try map.put("cx", 0);
    try map.put("dx", 0);
    try map.put("sp", 0);
    try map.put("bp", 0);
    try map.put("si", 0);
    try map.put("di", 0);
}

fn print_hash_map(map: std.StringHashMap(u16)) void {
    std.debug.print("\nREGISTER STATE\n", .{});
    std.debug.print("ax: {d}\n", .{map.get("ax").?});
    std.debug.print("  al: {d}\n", .{get_low(map.get("ax").?)});
    std.debug.print("  ah: {d}\n", .{get_high(map.get("ax").?)});
    std.debug.print("bx: {d}\n", .{map.get("bx").?});
    std.debug.print("  bl: {d}\n", .{get_low(map.get("bx").?)});
    std.debug.print("  bh: {d}\n", .{get_high(map.get("bx").?)});
    std.debug.print("cx: {d}\n", .{map.get("cx").?});
    std.debug.print("  cl: {d}\n", .{get_low(map.get("cx").?)});
    std.debug.print("  ch: {d}\n", .{get_high(map.get("cx").?)});
    std.debug.print("dx: {d}\n", .{map.get("dx").?});
    std.debug.print("  dl: {d}\n", .{get_low(map.get("dx").?)});
    std.debug.print("  dh: {d}\n", .{get_high(map.get("dx").?)});
    std.debug.print("sp: {d}\n", .{map.get("sp").?});
    std.debug.print("bp: {d}\n", .{map.get("bp").?});
    std.debug.print("si: {d}\n", .{map.get("si").?});
    std.debug.print("di: {d}\n", .{map.get("di").?});
    std.debug.print("\n", .{});
}

fn run_asm(regs: *cpu_regs) !void {
    if (std.mem.eql(u8, a.full_instr.opcode, "mov")) {
        try simulate_mov(regs);
    } else if (std.mem.eql(u8, a.full_instr.opcode, "sub")) {
        try simulate_sub(regs);
    } else if (std.mem.eql(u8, a.full_instr.opcode, "add")) {
        try simulate_add(regs);
    } else if (std.mem.eql(u8, a.full_instr.opcode, "cmp")) {
        try simulate_cmp(regs);
    }
}

fn simulate_mov(regs: *cpu_regs) !void {
    const dest: []const u8 = a.full_instr.dest_operand;
    var new_value: u16 = undefined;
    switch (a.full_instr.src_operand) {
        .data => |data| {
            std.debug.print("{s} {s}, {d}; ", .{ a.full_instr.opcode, dest, data });
            new_value = data;
        },
        .reg => |reg| {
            std.debug.print("{s} {s}, {s}; ", .{ a.full_instr.opcode, dest, reg });
            new_value = regs.get(reg);
        },
        .memory => {},
    }
    std.debug.print(" {s} ({d} -> {d})\n", .{ dest, regs.get(dest), new_value });
    try regs.put(dest, new_value);
}

fn simulate_add(regs: *cpu_regs) !void {
    const dest = a.full_instr.dest_operand;
    var sum: u16 = 0;
    switch (a.full_instr.src_operand) {
        .reg => |reg| {
            std.debug.print("{s} {s}, {s};", .{ a.full_instr.opcode, dest, reg });
            sum = regs.get(dest) + regs.get(reg);
        },

        .data => |data| {
            std.debug.print("{s} {s}, {d}; ", .{ a.full_instr.opcode, dest, data });
            sum = regs.get(dest) + data;
        },

        .memory => |_| {},
    }

    std.debug.print(" {s} ({d} -> {d})", .{ dest, regs.get(dest), sum });
    try regs.put(dest, sum);

    try handle_flags(sum);

    std.debug.print("\n", .{});
}

fn simulate_cmp(regs: *cpu_regs) !void {
    //NOTE: Simulate works like sub without setting the difference into the destination
    //Because subtracting the operands: if the difference is 0, then both operands are the same. Else they aren't.
    const dest = a.full_instr.dest_operand;
    var difference: u16 = 0;
    switch (a.full_instr.src_operand) {
        .reg => |reg| {
            std.debug.print("{s} {s}, {s};", .{ a.full_instr.opcode, dest, reg });
            difference = regs.get(dest) - regs.get(reg);
        },

        .data => |data| {
            std.debug.print("{s} {s}, {d}; ", .{ a.full_instr.opcode, dest, data });
            difference = regs.get(dest) - data;
        },

        .memory => |_| {},
    }

    try handle_flags(difference);

    std.debug.print("\n", .{});
}

fn simulate_sub(regs: *cpu_regs) !void {
    const dest = a.full_instr.dest_operand;
    var difference: u16 = 0;
    switch (a.full_instr.src_operand) {
        .reg => |reg| {
            std.debug.print("{s} {s}, {s};", .{ a.full_instr.opcode, dest, reg });
            difference = regs.get(dest) - regs.get(reg);
        },

        .data => |data| {
            std.debug.print("{s} {s}, {d}; ", .{ a.full_instr.opcode, dest, data });
            difference = regs.get(dest) - data;
        },

        .memory => |_| {},
    }

    std.debug.print(" {s} ({d} -> {d})", .{ dest, regs.get(dest), difference });
    try regs.put(dest, difference);

    try handle_flags(difference);

    std.debug.print("\n", .{});
}

fn handle_flags(value: u16) !void {
    if (value == 0) {
        a.set_zeroflag();
    } else {
        a.unset_zeroflag();
    }

    if ((value & 0b1000_000_000_000_000) > 0) {
        a.set_signflag();
    } else {
        a.unset_signflag();
    }

    if (a.is_set_zeroflag() or a.is_set_signflag()) {
        var flags: []const u8 = "";
        var buffer: [1024]u8 = [_]u8{undefined} ** 1024;

        if (a.is_set_zeroflag()) flags = try std.fmt.bufPrint(&a.buffer, "{s}{s}", .{ flags, "Z" });
        if (a.is_set_signflag()) flags = try std.fmt.bufPrint(&buffer, "{s}{s}", .{ flags, "S" });

        std.debug.print(" Flags: -> {s}", .{flags});
    }
}

fn mov_immediate(bytes: []u8, writer: std.fs.File.Writer) !void {
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
    a.full_instr = .{
        .opcode = "mov",
        .src_operand = source_operand{ .data = a.data.? },
        .dest_operand = a.reg,
    };
}

fn pattern_register_to_register(bytes: []u8, writer: std.fs.File.Writer, instr_type: []const u8) !void {
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

        a.full_instr.opcode = instr_type;
        a.full_instr.src_operand = source_operand{ .reg = a.reg };

        switch (a.mod) {
            0b01 => a.full_instr.dest_operand = try std.fmt.bufPrint(&a.buffer, "[{s} + {d}]", .{ a.r_m, a.disp_l }),
            0b10 => a.full_instr.dest_operand = try std.fmt.bufPrint(&a.buffer, "[{s} + {d}]", .{ a.r_m, ((a.disp_h << 8) | a.disp_l) }),
            0b00 => a.full_instr.dest_operand = try std.fmt.bufPrint(&a.buffer, "[{s}]", .{a.r_m}),
            0b11 => a.full_instr.dest_operand = try std.fmt.bufPrint(&a.buffer, "{s}", .{a.r_m}),
        }
    } else {
        switch (a.mod) {
            0b01 => try writer.print("{s} {s}, [{s} + {d}]\n", .{ instr_type, a.reg, a.r_m, a.disp_l }),
            0b10 => try writer.print("{s} {s}, [{s} + {d}]\n", .{ instr_type, a.reg, a.r_m, ((a.disp_h << 8) | a.disp_l) }),
            0b00 => try writer.print("{s} {s}, [{s}]\n", .{ instr_type, a.reg, a.r_m }),
            0b11 => try writer.print("{s} {s}, {s}\n", .{ instr_type, a.reg, a.r_m }),
        }

        a.full_instr.opcode = instr_type;
        a.full_instr.dest_operand = a.reg;

        switch (a.mod) {
            0b01 => a.full_instr.src_operand.reg = try std.fmt.bufPrint(&a.buffer, "[{s} + {d}]", .{ a.r_m, a.disp_l }),
            0b10 => a.full_instr.src_operand.reg = try std.fmt.bufPrint(&a.buffer, "[{s} + {d}]", .{ a.r_m, ((a.disp_h << 8) | a.disp_l) }),
            0b00 => a.full_instr.src_operand.reg = try std.fmt.bufPrint(&a.buffer, "[{s}]", .{a.r_m}),
            0b11 => a.full_instr.src_operand.reg = try std.fmt.bufPrint(&a.buffer, "{s}", .{a.r_m}),
        }
    }
    i += a.byte_count;
}

fn pattern_immediate_register_memory(bytes: []u8, writer: std.fs.File.Writer) !void {
    const byte1 = bytes[i];
    const byte2 = bytes[i + 1];
    a.s = if ((byte1 & 0b000000_1_0) > 0) 1 else 0;
    a.w = if ((byte1 & 0b0000000_1) > 0) 1 else 0;
    a.mod = get_mod_field(byte2);
    a.byte_count = 2;

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

    a.full_instr.opcode = instr;
    a.full_instr.src_operand = source_operand{ .data = a.data.? };

    switch (a.mod) {
        0b01 => a.full_instr.dest_operand = try std.fmt.bufPrint(&a.buffer, "{s} [{s} + {d}]", .{ a.byte_word, a.r_m, a.disp_l }),
        0b10 => a.full_instr.dest_operand = try std.fmt.bufPrint(&a.buffer, "{s} [{s} + {d}]", .{ a.byte_word, a.r_m, ((a.disp_h << 8) | a.disp_l) }),
        0b00 => a.full_instr.dest_operand = try std.fmt.bufPrint(&a.buffer, "{s} [{s}]", .{ a.byte_word, a.r_m }),
        0b11 => a.full_instr.dest_operand = try std.fmt.bufPrint(&a.buffer, "{s}", .{a.r_m}),
    }
    i += a.byte_count;
}

fn pattern_immediate_from_accumalator(bytes: []u8, writer: std.fs.File.Writer, instr_type: []const u8) !void {
    const byte1 = bytes[i];
    const byte2 = bytes[i + 1];
    var byte3: u16 = undefined;
    a.w = if ((byte1 & 0b0000000_1) > 0) 1 else 0;

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
    a.full_instr.opcode = instr_type;
    a.full_instr.src_operand = source_operand{ .data = a.data.? };
    a.full_instr.dest_operand = try std.fmt.bufPrint(&a.buffer, "{s}", .{a.reg});
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
    a.full_instr.opcode = opcode;
    a.full_instr.dest_operand = try std.fmt.bufPrint(&a.buffer, "{s} {d}", .{ opcode, ip_inc8 }); // FIXME: not right
    i += 2;
}
