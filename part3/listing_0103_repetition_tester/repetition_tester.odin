package tester

import "core:fmt"
import "core:mem"
import "core:os"
import "core:simd/x86"
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
	min:     u64,
	max:     u64,
	sum:     u64,
	counter: u64,
}

repetition_tester :: struct {
	cpu_freq:           u64,
	timer_start:        i64,
	timer_limit_in_s:   i64,
	start_cycle:        u64,
	process_byte_count: int,
	open_block_count:   u64,
	end_block_count:    u64,
	results:            repetition_test_results,
}

initialize_tester :: proc(time_limit_in_s: i64 = 10) -> (tester: repetition_tester) {
	tester = repetition_tester {
		timer_start = time.now()._nsec,
		timer_limit_in_s = time_limit_in_s,
		cpu_freq = get_CPU_Freq(),
		results = {min = (1 << 64) - 1},
	}
	fmt.printfln("CPU-FREQ: %d", tester.cpu_freq)
	return tester
}

begin_time :: proc(tester: ^repetition_tester) {
	tester.start_cycle = x86._rdtsc()
	tester.open_block_count += 1
}

end_time :: proc(tester: ^repetition_tester) {
	end_cycle := x86._rdtsc()
	tester.end_block_count += 1

	assert(tester.process_byte_count > 0, "no data been processed")
	assert(
		tester.open_block_count == tester.end_block_count,
		"unbalanced begin_time and end_time need to be called balanced",
	)

	elapsed_cycle := end_cycle - tester.start_cycle

	tester.results.sum += elapsed_cycle
	tester.results.counter += 1

	if elapsed_cycle < tester.results.min {
		tester.results.min = elapsed_cycle
		tester.timer_start = time.now()._nsec // reset timer
		fmt.printf(
			"min: %d c | %.2f ms | %.2f gb/s \r",
			tester.results.min,
			(f64(tester.results.min) / f64(tester.cpu_freq)) * 1000,
			(f64(tester.process_byte_count) / f64(mem.Gigabyte)) /
			(f64(tester.results.min) / f64(tester.cpu_freq)),
		)
	} else if elapsed_cycle > tester.results.max {
		tester.results.max = elapsed_cycle
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
	avg := results.sum / results.counter

	min_in_s := f64(results.min) / f64(tester.cpu_freq)
	max_in_s := f64(results.max) / f64(tester.cpu_freq)
	avg_in_s := f64(avg) / f64(tester.cpu_freq)

	fmt.printfln(
		"min: %d c | %.2f ms | %.2f gb/s ",
		results.min,
		min_in_s * 1000,
		(f64(tester.process_byte_count) / f64(mem.Gigabyte)) / min_in_s,
	)

	fmt.printfln(
		"max: %d c | %.2f ms | %.2f gb/s ",
		results.max,
		max_in_s * 1000,
		(f64(tester.process_byte_count) / f64(mem.Gigabyte)) / max_in_s,
	)

	fmt.printfln(
		"avg: %d c | %.2f ms | %.2f gb/s ",
		avg,
		avg_in_s * 1000,
		(f64(tester.process_byte_count) / f64(mem.Gigabyte)) / avg_in_s,
	)

	fmt.println()
}
