package profiler

import "../timer"
import "core:fmt"

measurements: #soa[dynamic]Info

@(init)
startup :: proc() {
	reserve(&measurements, 4096)
}

Info :: struct {
	proc_name:  string,
	start_tsc:  i64,
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

	assert(measurements.proc_name[0] == "total")

	fmt.println("\nPROFILING RESULTS")
	for info in measurements {
		fmt.printfln(
			"proc: %s[%d] %d, %.2f%%",
			info.proc_name,
			info.call_count,
			info.duration,
			(f64(info.duration) * 100) / f64(measurements.duration[0]),
		)
	}
}

time_block_start :: proc(name: string) {
	start := timer.read_cpu_timer()

	idx, found := find(name)
	if found {
		info := &measurements[idx]
		info.start_tsc = start
		info.call_count += 1
	} else {
		info := Info {
			proc_name = name,
			start_tsc = start,
		}
		info.call_count += 1
		append_soa(&measurements, info)
	}
}

find :: proc(name: string) -> (idx: int, found: bool) {
	for info, i in measurements {
		if info.proc_name == name {
			return i, true
		}
	}
	return 0, false
}

time_block_end :: proc(name: string) {
	idx, found := find(name)
	assert(found)

	info := &measurements[idx]

	start := info.start_tsc
	end := timer.read_cpu_timer()
	result := end - start

	info.duration += result
}
