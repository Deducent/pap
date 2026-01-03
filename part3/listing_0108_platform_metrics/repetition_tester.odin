package tester

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:simd/x86"
import "core:strings"
import "core:sys/linux"
import "core:time"

get_CPU_Freq :: proc() -> u64 {
	cycle_start := x86._rdtsc()

	start_timer := time.now()._nsec
	one_second: for {
		end_timer := time.now()._nsec
		elapsed_time := (end_timer - start_timer) / i64(time.Second)
		if elapsed_time >= 1 {
			break
		}
	}
	cycle_end := x86._rdtsc()
	elapsed_cycle := cycle_end - cycle_start

	return elapsed_cycle
}


repetition_test_results :: struct {
	min_cycle: u64,
	max_cycle: u64,
	sum_cycle: u64,
	min_page:  int,
	max_page:  int,
	sum_page:  int,
	counter:   u64,
}

allocation_type :: enum u8 {
	NONE, // one alloc before all test
	ALLOC, // alloc per test
}

repetition_tester :: struct {
	cpu_freq:           u64,
	timer_start:        i64,
	timer_limit_in_s:   i64,
	start_cycle:        u64,
	target_byte_count:  int,
	process_byte_count: int,
	open_block_count:   u64,
	end_block_count:    u64,
	results:            repetition_test_results,
	alloc_type:         allocation_type,
	dest_buffer:        []byte,
	default_buffer:     []byte,
	start_page:         int,
}

initialize_tester :: proc(
	target_size: int,
	all_type: allocation_type,
	default_buf: []byte,
	cpu_freq: u64,
	time_limit_in_s: i64 = 10,
) -> (
	tester: repetition_tester,
) {
	tester = repetition_tester {
		timer_start = time.now()._nsec,
		timer_limit_in_s = time_limit_in_s,
		cpu_freq = cpu_freq,
		results = {min_cycle = (1 << 64) - 1, min_page = (1 << 32) - 1},
		alloc_type = all_type,
		default_buffer = default_buf,
		target_byte_count = target_size,
	}


	fmt.printfln("CPU-FREQ: %d", tester.cpu_freq)
	return tester
}

handle_allocation :: proc(tester: ^repetition_tester) {
	switch tester.alloc_type {
	case .NONE:
		tester.dest_buffer = tester.default_buffer
	case .ALLOC:
		tester.dest_buffer = make([]byte, tester.target_byte_count, context.allocator)
	}
}

handle_deallocation :: proc(tester: ^repetition_tester) {
	switch tester.alloc_type {
	case .NONE:
		mem.zero_slice(tester.default_buffer)
	case .ALLOC:
		delete(tester.dest_buffer, context.allocator)
	}
}

begin_time :: proc(tester: ^repetition_tester) {
	tester.start_cycle = x86._rdtsc()
	tester.open_block_count += 1

	usage: linux.RUsage
	err_code := linux.getrusage(.SELF, &usage)
	assert(err_code == .NONE, fmt.tprintfln("Error code for start: %v", err_code))
	tester.start_page = usage.minflt_word + usage.majflt_word
}

end_time :: proc(tester: ^repetition_tester, loc := #caller_location) {
	end_cycle := x86._rdtsc()
	tester.end_block_count += 1

	assert(
		tester.process_byte_count == tester.target_byte_count,
		fmt.tprint("no data been processed %s", loc.procedure),
	)
	assert(
		tester.open_block_count == tester.end_block_count,
		"unbalanced begin_time and end_time need to be called balanced",
	)

	elapsed_cycle := end_cycle - tester.start_cycle
	tester.results.sum_cycle += elapsed_cycle
	tester.results.counter += 1

	usage: linux.RUsage
	err_code := linux.getrusage(.SELF, &usage)
	assert(err_code == .NONE, fmt.tprintfln("Error code for start: %v", err_code))
	end_page := usage.minflt_word + usage.majflt_word
	page_faults := end_page - tester.start_page

	tester.results.sum_page += page_faults

	if elapsed_cycle < tester.results.min_cycle {
		tester.results.min_cycle = elapsed_cycle
		tester.results.min_page = page_faults
		tester.timer_start = time.now()._nsec // reset timer

		print_stats("min", tester.results.min_cycle, tester^, page_faults)

	} else if elapsed_cycle > tester.results.max_cycle {
		tester.results.max_cycle = elapsed_cycle
		tester.results.max_page = page_faults
	}
}

is_testing :: proc(tester: repetition_tester) -> bool {
	timer_end := time.now()._nsec
	timer_elapsed := (timer_end - tester.timer_start) / i64(time.Second)
	if timer_elapsed >= tester.timer_limit_in_s {
		return false
	}
	return true
}

print_results :: proc(tester: repetition_tester) {
	results := tester.results
	avg_cycle := results.sum_cycle / results.counter
	avg_page := results.sum_page / int(results.counter)


	print_stats("min", results.min_cycle, tester, results.min_page, true)
	print_stats("max", results.max_cycle, tester, results.max_page, true)
	print_stats("avg", avg_cycle, tester, avg_page, true)
	fmt.println()

}

print_stats :: proc(
	label: string,
	cycle: u64,
	tester: repetition_tester,
	page_faults: int,
	new_line := false,
) {
	in_s := f64(cycle) / f64(tester.cpu_freq)
	b := strings.builder_make(context.temp_allocator)

	s := fmt.tprintf(
		"%s: %d c | %.2f ms | %.2f gb/s",
		label,
		cycle,
		in_s * 1000,
		(f64(tester.process_byte_count) / f64(mem.Gigabyte)) / in_s,
	)
	strings.write_string(&b, s)

	if page_faults > 0 {
		s := fmt.tprintf(
			" | Page_faults: %d (%.4f k/fault)",
			page_faults,
			f32(tester.process_byte_count / mem.Kilobyte) / f32(page_faults),
		)
		strings.write_string(&b, s)
	}

	if new_line {
		fmt.printfln("\r\033[K%s", strings.to_string(b))
	} else {
		fmt.printf("\r\033[K%s", strings.to_string(b))
	}
	free_all(context.temp_allocator)
}
