package profiler

import "../timer"
import "core:fmt"

measurements: [dynamic]Info

@(init)
startup :: proc() {
	reserve(&measurements, 4096)
}

Info :: struct {
	proc_name:         string,
	start_tsc:         i64,
	duration:          i64,
	children_duration: i64,
	call_count:        int,
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
	assert(measurements[0].proc_name == "total", "need to call begin_profile() first")

	time_block_end("total")

	fmt.println("\nPROFILING RESULTS")
	for info, idx in measurements {

		if info.children_duration > 0 && info.proc_name != "total" { 	// exclusiv_time
			exclusiv_time := info.duration - info.children_duration

			fmt.printfln(
				"proc: %s[%d] %d, %.2f%% with children | %d, %.2f%% without children",
				info.proc_name,
				info.call_count,
				info.duration,
				(f64(info.duration) * 100) / f64(measurements[0].duration),
				exclusiv_time,
				(f64(exclusiv_time) * 100) / f64(measurements[0].duration),
			)
		} else {
			fmt.printfln(
				"proc: %s[%d] %d, %.2f%%",
				info.proc_name,
				info.call_count,
				info.duration,
				(f64(info.duration) * 100) / f64(measurements[0].duration),
			)
		}
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
		new_info := Info {
			proc_name = name,
			start_tsc = start,
		}
		new_info.call_count += 1

		append(&measurements, new_info)
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
	assert(found, "not found entry")

	info := &measurements[idx]

	start := info.start_tsc
	end := timer.read_cpu_timer()
	result := end - start

	info.duration += result

	if idx != 0 {
		index_previous := idx - 1
		previous_entry := &measurements[index_previous]
		if previous_entry.duration == 0 { 	// check if parent or not
			previous_entry.children_duration = info.duration
		}
	}
}
