const std = @import("std");
const pow = std.math.pow;

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

pub fn main() !void {
    std.debug.print("{d}\n", .{ReferenceHaversine(20.123489, 39.585689, 124.1892387, 125.189797, 6372.8)});
}
