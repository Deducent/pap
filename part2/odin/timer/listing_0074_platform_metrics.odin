package timer

estimate_cpu_freq :: proc() -> i64 {
	os_start := read_os_timer()
	os_end: i64
	os_elapsed: i64

	cpu_start := read_cpu_timer()
	cpu_freq: i64
	return cpu_freq
}
