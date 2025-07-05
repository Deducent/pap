package timer

import "core:fmt"

estimate_cpu_freq :: proc() -> i64 {
	milisecond_to_wait: i64 = 1000
	os_wait_time := OS_TIME_FREQ * milisecond_to_wait / 1000

	os_start := read_os_timer()
	os_end: i64
	os_elapsed: i64

	cpu_start := read_cpu_timer()

	for os_elapsed < os_wait_time {
		os_end = read_os_timer()
		os_elapsed = os_end - os_start
	}

	cpu_end := read_cpu_timer()
	cpu_elapsed := cpu_end - cpu_start
	cpu_freq := OS_TIME_FREQ * cpu_elapsed / os_elapsed

	return cpu_freq
}
