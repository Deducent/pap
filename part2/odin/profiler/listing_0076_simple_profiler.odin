package profiler

import "../timer"
import "core:fmt"

measurements := make(map[string]Info, 4096)

Info :: struct {
	duration:   i64,
	call_count: int,
}

time_function :: proc(loc := #caller_location) {
	time_block_start(loc.procedure)
}

time_function_end :: proc(loc := #caller_location) {
	time_block_end(loc.procedure)
}

begin_profile :: proc() {
	time_block_start("total")
}

end_profile :: proc() {
	time_block_end("total")

	fmt.println("\nPROFILING RESULTS")
	for k, v in measurements {
		fmt.printfln(
			"proc: %s[%d] %d, %.2f%%",
			k,
			v.call_count,
			v.duration,
			(f64(v.duration) * 100) / f64(measurements["total"].duration),
		)
	}
}

time_block_start :: proc(name: string) {
	start := timer.read_cpu_timer()
	info := measurements[name] or_else Info{}
	info.duration = start
	info.call_count += 1
	measurements[name] = info
}

time_block_end :: proc(name: string) {
	assert(name in measurements)
	info := measurements[name]

	start := info.duration
	end := timer.read_cpu_timer()
	result := end - start

	info.duration = result
	measurements[name] = info
}
