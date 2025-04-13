package part2

import "core:fmt"
import "core:mem"
import "core:os"

import "haversine"
import "json_parser"


main :: proc() {
	data, ok := os.read_entire_file("./haversine/data.json", context.allocator)
	assert(ok, "Failed to read")
	defer delete(data, context.allocator)

	parsed := json_parser.parse(string(data))
	fmt.println(parsed)
	pairs := parsed.(json_parser.Json_object)["pairs"].(json_parser.Json_list)

	data, ok = os.read_entire_file("./haversine/haversine.f64", context.allocator)
	assert(ok, "Failed to read")
	answers_f64 := mem.slice_data_cast([]f64, data)
	fmt.println(answers_f64)

	sum: f64
	for pair in pairs {
		object := pair.(json_parser.Json_object)
		x0 := object["x0"].(f64)
		y0 := object["y0"].(f64)
		x1 := object["x1"].(f64)
		y1 := object["y1"].(f64)

		sum += haversine.reference_haversine(x0, y0, x1, y1, haversine.EARTH_RADIUS)
	}

	avg := sum / f64(len(pairs))
	ref_avg := answers_f64[len(pairs)]

	fmt.println("average: ", avg)
	fmt.println("difference: ", avg - ref_avg)
}
