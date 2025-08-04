package profiler

import "../timer"
import sa "core:container/small_array"
import "core:fmt"
import "core:mem"
import "core:strings"

Profile_Block :: struct {
	start_tsc:  i64,
	parent_idx: int,
}

Profiler :: true

Info :: struct {
	proc_name:         string,
	duration:          i64,
	children_duration: i64,
	root_duration:     i64,
	call_count:        int,
	byte_count:        int,
}

global_parent_idx: int
global_old_root_duration: i64

infos: sa.Small_Array(10, Info)
profile_blocks: sa.Small_Array(10, Profile_Block)

time_function :: proc(loc := #caller_location, byte_count := 0) {
	when Profiler {
		time_block_start(loc.procedure, byte_count)
	}
}

time_function_end :: proc(loc := #caller_location, byte_count := 0) {
	when Profiler {
		time_block_end(loc.procedure, byte_count)
	}
}

begin_profile :: proc() {
	time_block_start("total")
}

end_profile :: proc() {
	measurements := infos.data[:]
	assert(measurements[0].proc_name == "total", "need to call begin_profile() first")

	time_block_end("total")

	CPU_FREQ := timer.estimate_cpu_freq()

	fmt.println("\nPROFILING RESULTS")
	for idx in 0 ..< infos.len {
		info := infos.data[idx]

		total_duration := f64(measurements[0].root_duration)

		if info.proc_name == "total" {
			fmt.printfln(
				"%s[%d] %d, %.2f%% | CPU FREQ (%d) | time: %.9f s",
				info.proc_name,
				info.call_count,
				info.root_duration,
				(f64(info.root_duration) * 100) / total_duration,
				CPU_FREQ,
				f64(info.root_duration) / f64(CPU_FREQ),
			)
		} else {
			output_string: string
			err: mem.Allocator_Error

			stats_string := fmt.tprintf(
				"proc: %s[%d] %d, %.2f%%",
				info.proc_name,
				info.call_count,
				info.root_duration,
				(f64(info.root_duration) * 100) / total_duration,
			)
			output_string = stats_string

			if info.children_duration > 0 {
				exclusiv_time := info.duration - info.children_duration
				exclusive_time_string := fmt.tprintf(
					" with children | %d, %.2f%% without children",
					exclusiv_time,
					(f64(exclusiv_time) * 100) / total_duration,
				)
				output_string, err = strings.concatenate(
					{stats_string, exclusive_time_string},
					context.temp_allocator,
				)
				assert(err == nil, fmt.aprint("failed concatenating strings ", err))
			}

			if info.byte_count > 0 {
				throughput_string := fmt.tprintf(
					" | %.9f mb  %.9f gig/s ",
					f64(info.byte_count) / mem.Megabyte,
					(f64(info.byte_count) / mem.Gigabyte) /
					(f64(info.root_duration) / f64(CPU_FREQ)),
				)
				err: mem.Allocator_Error
				output_string, err = strings.concatenate(
					{output_string, throughput_string},
					context.temp_allocator,
				)
				assert(err == nil, fmt.aprint("failed concatenating strings ", err))
			}

			fmt.println(output_string)
		}
	}
}

time_block_start :: proc(name: string, byte_count := 0) {
	when !Profiler {
		if name != "total" {
			return
		}
	}
	idx, found := find(name)
	start := timer.read_cpu_timer()
	sa.append(&profile_blocks, Profile_Block{start_tsc = start, parent_idx = global_parent_idx})
	if found {
		info := &infos.data[idx]
		info.call_count += 1
		info.root_duration = global_old_root_duration
		info.byte_count += byte_count

		global_parent_idx = idx
	} else {
		new_info := Info {
			proc_name     = name,
			root_duration = global_old_root_duration,
			byte_count    = byte_count,
		}
		new_info.call_count += 1
		sa.append(&infos, new_info)

		global_parent_idx = infos.len - 1
	}
}

find :: proc(name: string) -> (idx: int, found: bool) {
	for idx in 0 ..< infos.len {
		info := infos.data[idx]

		if info.proc_name == name {
			return idx, true
		}
	}
	return 0, false
}

time_block_end :: proc(name: string, byte_count := 0) {
	when !Profiler {
		if name != "total" {
			return
		}
	}
	end := timer.read_cpu_timer()
	idx, found := find(name)
	assert(found, "not found entry")

	info := &infos.data[idx]

	current_profile_block := profile_blocks.data[profile_blocks.len - 1]
	start := current_profile_block.start_tsc
	elapsed := end - start

	info.duration += elapsed
	info.root_duration = global_old_root_duration + elapsed

	if idx != 0 {
		parent_info := &infos.data[current_profile_block.parent_idx]
		parent_info.children_duration += elapsed
	}
	global_parent_idx = current_profile_block.parent_idx
	profile_blocks.len -= 1

}
