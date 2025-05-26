package profiler

import "../timer"
import "core:fmt"

measurements: map[string]i64

time_function :: proc(loc := #caller_location) {
	start := timer.read_cpu_timer()
	measurements[loc.procedure] = start
}

time_function_end :: proc(loc := #caller_location) {
	start := measurements[loc.procedure]
	end := timer.read_cpu_timer()
	result := end - start
	measurements[loc.procedure] = result
}

begin_profile :: proc() {
	start := timer.read_cpu_timer()
	measurements["total"] = start
}

end_profile :: proc() {
	start := measurements["total"]
	end := timer.read_cpu_timer()
	total := end - start
	measurements["total"] = total
	for k, v in measurements {
		fmt.printfln("proc: %s, %d, %.2f%%", k, v, (f64(v) * 100) / f64(total))
	}
}

time_block_start :: proc(name: string) {
	start := timer.read_cpu_timer()
	measurements[name] = start
}

time_block_end :: proc(name: string) {
	start := measurements[name]
	end := timer.read_cpu_timer()
	result := end - start
	measurements[name] = result
}
