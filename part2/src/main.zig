const std = @import("std");
const generator = @import("listing_0066_haversine_generator_main.zig");
const pow = std.math.pow;
const eql = std.mem.eql;
const asin = std.math.asin;
const rand = std.crypto.random;

fn RadiansFromDegrees(degrees: f64) f64 {
    return 0.01745329251994329577 * degrees;
}



/// NOTE(casey): EarthRadius is generally expected to be 6372.8
fn ReferenceHaversine(x0: f64, y0: f64, x1: f64, y1: f64, EarthRadius: f64) f64 {
    var lat1: f64 = y0;
    var lat2: f64 = y1;
    const lon1 = x0;
    const lon2 = x1;

    const dlat = RadiansFromDegrees(lat2 - lat1);
    const dlon = RadiansFromDegrees(lon2 - lon1);
    lat1 = RadiansFromDegrees(lat1);
    lat2 = RadiansFromDegrees(lat2);

    const a = pow(f64, @sin(dlat / 2.0), 2) +  @cos(lat1) * @cos(lat2) *  pow(f64, @sin(dlon/2), 2);
    const c = 2.0 * asin(@sqrt(a));

    return EarthRadius * c;
}

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

    var series: ranctx = seed(Config.seed);
    _ = try file.write(
        \\{
        \\  pairs:
        \\      [
    );

    const maxAllowedX: f64 = 180;
    const maxAllowedY: f64 = 90;
    var sum: f64 = 0;
    for (0..Config.data_amount) |_| {
        const x1 = RandomDegree(&series, 0, 180, maxAllowedX);
        const y1 = RandomDegree(&series, 0, 90, maxAllowedY);
        const x2 = RandomDegree(&series, 0, 180, maxAllowedX);
        const y2 = RandomDegree(&series, 0, 90, maxAllowedY);
        sum += ReferenceHaversine(x1, y1, x2, y2, 6372.8);
        std.debug.print("sum: {d}\n", .{sum});
    }

    std.debug.print("average haversine {d}\n", .{sum / @as(f64, @floatFromInt(Config.data_amount))});

    // std.debug.print("{d}\n {d}\n {d}\n {d}\n", .{ x1, x2, y1, y2 });

    _ = try file.write(
        \\      ]
        \\}
    );
}
