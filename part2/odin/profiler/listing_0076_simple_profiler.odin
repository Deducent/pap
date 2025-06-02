package profiler

import "../timer"
import "core:fmt"

measurements: map[string]Info

Info :: struct {
	duration:   i64,
	call_count: int,
}

time_function :: proc(loc := #caller_location) {
	start := timer.read_cpu_timer()
	info, ok := measurements[loc.procedure]
	if !ok {
		info = Info {
			duration = start,
		}
	}
	info.call_count += 1
	measurements[loc.procedure] = info
}

time_function_end :: proc(loc := #caller_location) {
	assert(loc.procedure in measurements)

	info := measurements[loc.procedure]

	start := info.duration
	end := timer.read_cpu_timer()
	result := end - start

	info.duration = result
	measurements[loc.procedure] = info

}

begin_profile :: proc() {
	start := timer.read_cpu_timer()
	info, ok := measurements["total"]
	if !ok {
		info = Info {
			duration = start,
		}
	}
	info.call_count += 1
	measurements["total"] = info
}

end_profile :: proc() {
	assert("total" in measurements)
	info := measurements["total"]

	start := info.duration
	end := timer.read_cpu_timer()
	total := end - start

	info.duration = total
	measurements["total"] = info

	fmt.println("\nPROFILING RESULTS")
	for k, v in measurements {
		fmt.printfln(
			"proc: %s[%d] %d, %.2f%%",
			k,
			v.call_count,
			v.duration,
			(f64(v.duration) * 100) / f64(total),
		)
	}
}

time_block_start :: proc(name: string) {
	start := timer.read_cpu_timer()
	info, ok := measurements[name]
	if !ok {
		info = Info {
			duration = start,
		}
	}
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
