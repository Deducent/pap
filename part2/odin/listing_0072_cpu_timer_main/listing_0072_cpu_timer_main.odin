package part2

import "core:fmt"
import "timer"

main :: proc() {
	os_start := timer.read_os_timer()
	os_end: i64
	os_elapsed: i64

	cpu_start := timer.read_cpu_timer()

	for os_elapsed < timer.OS_TIME_FREQ {
		os_end = timer.read_os_timer()
		os_elapsed = os_end - os_start
	}

	cpu_end := timer.read_cpu_timer()
	cpu_elapsed := cpu_end - cpu_start

	fmt.printfln("OS TIMER : %i -> %i = %i elapsed", os_start, os_end, os_elapsed)
	fmt.printfln("OS Seconds: %.4f", f64(os_elapsed) / f64(timer.OS_TIME_FREQ))

	fmt.printfln("cpu TIMER : %i -> %i = %i elapsed", cpu_start, cpu_end, cpu_elapsed)
}
