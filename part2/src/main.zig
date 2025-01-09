const std = @import("std");
const generator = @import("listing_0066_haversine_generator_main.zig");
const pow = std.math.pow;
const eql = std.mem.eql;

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
};

var Config: config = config{};

pub fn main() !void {
    var args = std.process.args();
    defer args.deinit();

    _ = args.skip();

    while (args.next()) |arg| {
        std.debug.print("{s}\n", .{arg});
        if (eql(u8, "--generate", arg)) {
            Config.generate = true;
        } else if (eql(u8, "--cluster", arg)) {
            Config.cluster = true;
        }
    }

    std.debug.print("config: {any}", .{Config});
    std.debug.print("\n", .{});
    const file = try std.fs.cwd().createFile("data.json", .{ .read = true });
    defer file.close();

    _ = try file.write(
        \\{
        \\  pairs:
        \\      [
    );

    _ = try file.write(
        \\      ]
        \\}
    );
}
