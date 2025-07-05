package part2

import "core:fmt"
import "core:os"
import "core:strconv"
import "timer"

main :: proc() {
	mili_seconds_to_wait: i64 = 1000
	if len(os.args) == 2 {
		ok: bool
		mili_seconds_to_wait, ok = strconv.parse_i64(os.args[1])
		assert(ok, "not a number")
	}
	os_wait_time := timer.OS_TIME_FREQ * mili_seconds_to_wait / 1_000

	os_start := timer.read_os_timer()
	os_end: i64
	os_elapsed: i64

	cpu_start := timer.read_cpu_timer()

	for os_elapsed < os_wait_time {
		os_end = timer.read_os_timer()
		os_elapsed = os_end - os_start
	}

	cpu_end := timer.read_cpu_timer()
	cpu_elapsed := cpu_end - cpu_start
	cpu_freq := timer.OS_TIME_FREQ * cpu_elapsed / os_elapsed

	fmt.printfln("OS TIMER : %i -> %i = %i elapsed", os_start, os_end, os_elapsed)
	fmt.printfln("OS Seconds: %.4f", f64(os_elapsed) / f64(timer.OS_TIME_FREQ))

	fmt.printfln("cpu TIMER : %i -> %i = %i elapsed", cpu_start, cpu_end, cpu_elapsed)
	fmt.printfln("cpu freq: %i", cpu_freq)
}
