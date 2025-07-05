package profiler

import "../timer"
import sa "core:container/small_array"
import "core:fmt"

Info :: struct {
	proc_name:         string,
	start_tsc:         i64,
	duration:          i64,
	children_duration: i64,
	call_count:        int,
}

infos: sa.Small_Array(10, Info)

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
	measurements := infos.data[:]
	assert(measurements[0].proc_name == "total", "need to call begin_profile() first")

	time_block_end("total")

	fmt.println("\nPROFILING RESULTS")
	for idx in 0 ..< infos.len {
		info := infos.data[idx]

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
	idx, _, found := find(name)
	start := timer.read_cpu_timer()
	if found {
		info := &infos.data[idx]
		info.start_tsc = start
		info.call_count += 1
	} else {
		new_info := Info {
			proc_name = name,
			start_tsc = start,
		}
		new_info.call_count += 1

		sa.append(&infos, new_info)
	}
}

find :: proc(name: string) -> (idx: int, parent_idx: int, found: bool) {
	for idx in 0 ..< infos.len {
		info := infos.data[idx]

		if info.duration == 0 && info.proc_name != name {
			parent_idx = idx
		}

		if info.proc_name == name {
			return idx, parent_idx, true
		}
	}
	return 0, parent_idx, false
}

time_block_end :: proc(name: string) {
	end := timer.read_cpu_timer()
	idx, parent_idx, found := find(name)
	assert(found, "not found entry")

	info := &infos.data[idx]

	start := info.start_tsc
	result := end - start

	info.duration += result

	if idx != 0 {
		parent_info := &infos.data[parent_idx]
		parent_info.children_duration += result
	}
}
