package timer

import "base:intrinsics"
import "core:fmt"
import "core:time"

OS_TIME_FREQ :: 1_000_000_000 // NOTE: one second in nanoseconds

read_cpu_timer :: proc() -> i64 {
	return intrinsics.read_cycle_counter() // NOTE: maps to rdtsc
}

read_os_timer :: proc() -> i64 {
	now := time.now()
	return now._nsec
}

main :: proc() {
	fmt.println(read_os_timer())
	fmt.println(read_cpu_timer())
	fmt.println(estimate_cpu_freq())
}
