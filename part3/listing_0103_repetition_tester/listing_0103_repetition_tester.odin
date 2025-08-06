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

main :: proc() {
	{
		min: u64 = (1 << 64) - 1
		max: u64
		avg: u64
		counter: u64
		data: []byte
		ok: bool

		fmt.println("1.CPU-FREQ")
		cpu_freq := get_CPU_Freq()
		fmt.printfln("CPU Time: %d", cpu_freq)
		fmt.println()

		timer_start := time.now()._nsec
		for {

			start_cycle := x86._rdtsc()

			data, ok = os.read_entire_file_from_filename(
				"../listing_0101_read_bandwidth_main/haversine/data.json",
			)

			end_cycle := x86._rdtsc()
			assert(ok, "failed to read the file")
			delete(data, context.allocator)

			elapsed := end_cycle - start_cycle

			if elapsed < min {
				min = elapsed
				timer_start = time.now()._nsec
				fmt.printf(
					"min: %d c | %.2f ms | %.2f gb/s \r",
					min,
					(f64(min) / f64(cpu_freq)) * 1000,
					(f64(len(data)) / f64(mem.Gigabyte)) / (f64(min) / f64(cpu_freq)),
				)
			} else if elapsed > max {
				max = elapsed
			}

			avg = avg + elapsed

			timer_end := time.now()._nsec
			timer_elapsed := (timer_end - timer_start) / i64(time.Second)
			if timer_elapsed >= 10 {
				break
			}
			counter += 1
		}
		avg /= counter

		min_in_s := f64(min) / f64(cpu_freq)
		max_in_s := f64(max) / f64(cpu_freq)
		avg_in_s := f64(avg) / f64(cpu_freq)

		fmt.printfln(
			"min: %d c | %.2f ms | %.2f gb/s ",
			min,
			min_in_s * 1000,
			(f64(len(data)) / f64(mem.Gigabyte)) / min_in_s,
		)

		fmt.printfln(
			"max: %d c | %.2f ms | %.2f gb/s ",
			max,
			max_in_s * 1000,
			(f64(len(data)) / f64(mem.Gigabyte)) / max_in_s,
		)

		fmt.printfln(
			"avg: %d c | %.2f ms | %.2f gb/s ",
			avg,
			avg_in_s * 1000,
			(f64(len(data)) / f64(mem.Gigabyte)) / avg_in_s,
		)

		fmt.println()
	}

	{
		min: u64 = (1 << 64) - 1
		max: u64
		avg: u64
		counter: u64
		data: []byte
		err: os.Error

		fmt.println("2.CPU-FREQ")
		cpu_freq := get_CPU_Freq()
		fmt.printfln("CPU Time: %d", cpu_freq)
		fmt.println()

		timer_start := time.now()._nsec
		for {

			file_data, miss := os.open("../listing_0101_read_bandwidth_main/haversine/data.json")
			assert(miss == nil, "failed to open the file")

			start_cycle := x86._rdtsc()
			data, err = os.read_entire_file_from_handle_or_err(file_data)
			end_cycle := x86._rdtsc()

			assert(err == nil, "failed to read the file")
			delete(data, context.allocator)

			defer os.close(file_data)

			elapsed := end_cycle - start_cycle

			if elapsed < min {
				min = elapsed
				timer_start = time.now()._nsec
				fmt.printf(
					"min: %d c | %.2f ms | %.2f gb/s \r",
					min,
					(f64(min) / f64(cpu_freq)) * 1000,
					(f64(len(data)) / f64(mem.Gigabyte)) / (f64(min) / f64(cpu_freq)),
				)
			} else if elapsed > max {
				max = elapsed
			}

			avg = avg + elapsed

			timer_end := time.now()._nsec
			timer_elapsed := (timer_end - timer_start) / i64(time.Second)
			if timer_elapsed >= 10 {
				break
			}
			counter += 1
		}
		avg /= counter

		min_in_s := f64(min) / f64(cpu_freq)
		max_in_s := f64(max) / f64(cpu_freq)
		avg_in_s := f64(avg) / f64(cpu_freq)

		fmt.printfln(
			"min: %d c | %.2f ms | %.2f gb/s ",
			min,
			min_in_s * 1000,
			(f64(len(data)) / f64(mem.Gigabyte)) / min_in_s,
		)

		fmt.printfln(
			"max: %d c | %.2f ms | %.2f gb/s ",
			max,
			max_in_s * 1000,
			(f64(len(data)) / f64(mem.Gigabyte)) / max_in_s,
		)

		fmt.printfln(
			"avg: %d c | %.2f ms | %.2f gb/s ",
			avg,
			avg_in_s * 1000,
			(f64(len(data)) / f64(mem.Gigabyte)) / avg_in_s,
		)

		fmt.println()
	}
}
