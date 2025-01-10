const std = @import("std");
const generator = @import("listing_0066_haversine_generator_main.zig");
const pow = std.math.pow;
const eql = std.mem.eql;
// const rand = std.crypto.random;

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

    const a = pow(f64, @sin(dlat / 2.0) + @cos(lat1) * @cos(lat2) * pow(f64, dlon, 2), 2);
    const c = 2.0 * @sqrt(a);

    return EarthRadius * c;
}

const config = struct {
    generate: bool = false,
    cluster: bool = false,
    seed: u32 = 0,
    data_amount: u32 = 0,
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
            Config.seed = std.fmt.parseInt(u32, args.next().?, 10) catch |e| {
                std.debug.print("{any} Invalid Character please enter a numerical value\n", .{e});
                return;
            };
        } else if (eql(u8, "--amount", arg)) {
            Config.data_amount = std.fmt.parseInt(u32, args.next().?, 10) catch |e| {
                std.debug.print("{any} Invalid Character please enter a numerical value\n", .{e});
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

pub fn main() !void {
    process_args();

    var prng = std.Random.DefaultPrng.init(blk: {
        try std.posix.getrandom(std.mem.asBytes(&Config.seed));
        break :blk Config.seed;
    });
    const rand = prng.random();

    std.debug.print("config: {any}", .{Config});
    std.debug.print("\n", .{});
    const file = try std.fs.cwd().createFile("data.json", .{ .read = true });
    defer file.close();

    _ = try file.write(
        \\{
        \\  pairs:
        \\      [
    );

    var sum: f64 = 0;
    for (0..Config.data_amount) |_| {
        const x1 = rand.float(f64) * 180;
        const x2 = rand.float(f64) * 180;
        const y1 = rand.float(f64) * 90;
        const y2 = rand.float(f64) * 90;

        sum += ReferenceHaversine(x1, y1, x2, y2, 6372.8);
    }

    std.debug.print("average haversine {d}\n", .{sum / @as(f64, @floatFromInt(Config.data_amount))});

    // std.debug.print("{d}\n {d}\n {d}\n {d}\n", .{ x1, x2, y1, y2 });

    _ = try file.write(
        \\      ]
        \\}
    );
}
