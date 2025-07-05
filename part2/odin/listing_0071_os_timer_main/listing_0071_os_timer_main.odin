package part2

import "core:fmt"
import "timer"

main :: proc() {
	os_start := timer.read_os_timer()
	os_end: i64
	os_elapsed: i64

	for os_elapsed < timer.OS_TIME_FREQ {
		os_end = timer.read_os_timer()
		os_elapsed = os_end - os_start
	}

	fmt.printfln("OS TIMER : %i -> %i = %i elapsed", os_start, os_end, os_elapsed)
	fmt.printfln("OS Seconds: %.4f", f64(os_elapsed) / f64(timer.OS_TIME_FREQ))
}
