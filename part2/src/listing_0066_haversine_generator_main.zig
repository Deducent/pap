const std = @import("std");
const pow = std.math.pow;
const eql = std.mem.eql;
const ReferenceHaversine = @import("haversine_formula.zig").ReferenceHaversine;


const config = struct {
    generate: bool = false,
    cluster: bool = false,
    seed: u64 = 0,
    data_amount: usize = 0,
};

var Config: config = config{};

fn process_args() void {
    var args = std.process.args();
    defer args.deinit();

    _ = args.skip();

    while (args.next()) |arg| {
        std.debug.print("{s}\n", .{arg});
        if (eql(u8, "--generate", arg)) {
            Config.generate = true;
        } else if (eql(u8, "--cluster", arg)) {
            Config.cluster = true;
        } else if (eql(u8, "--seed", arg)) {
            Config.seed = std.fmt.parseInt(u64, args.next().?, 10) catch |e| {
                std.debug.print("{any} seed: Invalid Character please enter a numerical value\n", .{e});
                return;
            };
        } else if (eql(u8, "--amount", arg)) {
            Config.data_amount = std.fmt.parseInt(usize, args.next().?, 10) catch |e| {
                std.debug.print("{any} amount: Invalid Character please enter a numerical value\n", .{e});
                return;
            };
        } else {
            std.debug.print(
                \\ Usage
                \\ --generate -- for data.json generation
                \\ --seed <number> -- for seed
                \\ --amount <number> -- for amount of pairs of in data.json 
            , .{});
        }
    }
}

const u64MAX = pow(u65, 2, 64);
const ranctx = struct { a: u64, b: u64, c: u64, d: u64 };

inline fn rotate(v: u64, shift: u64) u64 {
    return (((v) << (shift) | (v) >> (64 - (shift))));
}

fn rand_value(x: *ranctx) u64 {
    const e = x.a -% rotate(x.b, 27);
    x.a = x.b ^ rotate(x.c, 17);
    x.b = x.c +% x.d;
    x.c = x.d +% e;
    x.d = e +% x.a;

    return x.d;
}

fn seed(value: u64) ranctx {
    var x: ranctx = ranctx{
        .a = 0xf1ea5eed,
        .b = value,
        .c = value,
        .d = value,
    };

    for (0..20) |_| {
        _ = rand_value(&x);
    }

    return x;
}

fn random_in_range(series: *ranctx, min: f64, max: f64) f64 {
    const vorne = @as(f64, @floatFromInt(rand_value(series)));
    const hinten = @as(f64, @floatFromInt(u64MAX));
    const t = vorne / hinten;
    return (1.0 - t) * min + t * max;
}

fn RandomDegree(series: *ranctx, center: f64, radius: f64, maxAllowed: f64) f64 {
    var minVal: f64 = center - radius;
    if (minVal < -maxAllowed) {
        minVal = -maxAllowed;
    }

    var maxVal: f64 = center + radius;
    if (maxVal > maxAllowed) {
        maxVal = maxAllowed;
    }

    const result: f64 = random_in_range(series, minVal, maxVal);
    return result;
}

pub fn main() !void {
    process_args();

    std.debug.print("config: {any}", .{Config});
    std.debug.print("\n", .{});
    const file = try std.fs.cwd().createFile("data.json", .{ .read = true });
    defer file.close();

    const haversineFile= try std.fs.cwd().createFile("haversine.f64", .{ .read = true });
    defer haversineFile.close();

    var series: ranctx = seed(Config.seed);
    _ = try file.write(
        \\{
        \\  pairs:
        \\      [
        \\          
    );

    var ClusterCountLeft = u64MAX;
    const maxAllowedX: f64 = 180;
    const maxAllowedY: f64 = 90;

    if (Config.cluster) {
        ClusterCountLeft = 0;
    } else {
        std.debug.print("WARNING: Unregcognized method name. Using 'uniform'.\n", .{});
    }

    const maxPairCount: u35 = (1 << 34);

    if (Config.data_amount >= maxPairCount) {
        std.debug.print("To avoid accidentally generating massive files, number of pairs must be less than {d}.\n", .{maxPairCount});
        return;
    }

    const clusterCountMax = 1 + (Config.data_amount / 64);
    var xCenter: f64 = 0;
    var yCenter: f64 = 0;
    var xRadius: f64 = maxAllowedX;
    var yRadius: f64 = maxAllowedY;

    var sum: f64 = 0;
    for (0..Config.data_amount) |i| {
        if (ClusterCountLeft == 0) {
            ClusterCountLeft = clusterCountMax;
            xCenter = random_in_range(&series, -maxAllowedX, maxAllowedX);
            yCenter = random_in_range(&series, -maxAllowedY, maxAllowedY);
            xRadius = random_in_range(&series, 0, maxAllowedX);
            yRadius = random_in_range(&series, 0, maxAllowedY);
        }

        ClusterCountLeft = ClusterCountLeft - 1;

        const x1 = RandomDegree(&series, xCenter, xRadius, maxAllowedX);
        const y1 = RandomDegree(&series, yCenter, yRadius, maxAllowedY);
        const x2 = RandomDegree(&series, xCenter, xRadius, maxAllowedX);
        const y2 = RandomDegree(&series, yCenter, yRadius, maxAllowedY);
        const writer = file.writer();
        try writer.print(
            \\ {{"x0": {d}, "y0": {d}, "x1": {d}, "y1": {d}}}
        , .{ x1, y1, x2, y2 });

        if (i != Config.data_amount - 1) try writer.print(",", .{});
        try writer.print("\n", .{});

        const haversine = ReferenceHaversine(x1, y1, x2, y2, 6372.8);
        try haversineFile.writeAll(to_bytes(haversine));

        sum += haversine;
    }

    try haversineFile.writeAll(to_bytes(sum));

    std.debug.print("average haversine {d}\n", .{sum / @as(f64, @floatFromInt(Config.data_amount))});

    _ = try file.write(
        \\      ]
        \\}
        \\
    );
}

inline fn to_bytes(num: anytype) []const u8 {
    return &@as([@sizeOf(@TypeOf(num))]u8, @bitCast(num));
}
