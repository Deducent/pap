package part2

import "core:fmt"
import "core:mem"
import "core:os"

import "haversine"
import "json_parser"
import "timer"

main :: proc() {
	prof_begin := timer.read_cpu_timer()

	data, ok := os.read_entire_file("./haversine/data.json", context.allocator)
	assert(ok, "Failed to read")
	defer delete(data, context.allocator)
	prof_read_end := timer.read_cpu_timer()

	parsed := json_parser.parse(string(data))
	prof_parse_end := timer.read_cpu_timer()

	pairs := parsed.(json_parser.Json_object)["pairs"].(json_parser.Json_list)

	data, ok = os.read_entire_file("./haversine/haversine.f64", context.allocator)
	assert(ok, "Failed to read")
	answers_f64 := mem.slice_data_cast([]f64, data)

	sum: f64
	for pair in pairs {
		object := pair.(json_parser.Json_object)
		x0 := object["x0"].(f64)
		y0 := object["y0"].(f64)
		x1 := object["x1"].(f64)
		y1 := object["y1"].(f64)

		sum += haversine.reference_haversine(x0, y0, x1, y1, haversine.EARTH_RADIUS)
	}
	pair_count := len(pairs)
	avg := sum / f64(pair_count)
	prof_sum_end := timer.read_cpu_timer()

	ref_avg := answers_f64[pair_count]

	fmt.println("pair count: ", pair_count)
	fmt.printfln("haversine average: %.16f", avg)
	fmt.printfln("reference average: %.16f", ref_avg)
	fmt.printfln("difference: %.16f", avg - ref_avg)

	prof_end := timer.read_cpu_timer()
	total_cpu_time := prof_end - prof_begin

	print_relative_time_elapsed("TOTAL", total_cpu_time, prof_begin, prof_end)
	print_relative_time_elapsed("READ", total_cpu_time, prof_begin, prof_read_end)
	print_relative_time_elapsed("PARSE", total_cpu_time, prof_read_end, prof_parse_end)
	print_relative_time_elapsed("SUM", total_cpu_time, prof_parse_end, prof_sum_end)
}

print_relative_time_elapsed :: proc(label: string, total_time: i64, start: i64, end: i64) {
	elapsed := end - start
	percent: f64 = (f64(elapsed) * 100) / f64(total_time)
	fmt.printfln("%s: %i %.2f%%", label, elapsed, percent)
}
