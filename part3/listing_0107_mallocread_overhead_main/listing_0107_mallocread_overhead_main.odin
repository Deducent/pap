package tester

import "base:runtime"
import "core:c/libc"
import "core:fmt"
import vmem "core:mem/virtual"
import "core:os"
import "core:reflect"

Test :: struct {
	label: string,
	func:  proc(tester: ^repetition_tester, file_name: string),
}

tests := [?]Test {
	{label = "read_via_readfile", func = read_via_readfile},
	{label = "read_entire_file_with_libc", func = read_entire_file_with_libc},
}

main :: proc() {
	file := "../listing_0101_read_bandwidth_main/haversine/data.json"
	infinite: bool

	for arg in os.args {
		if arg == "--inf" {
			infinite = true
		}
	}

	names := reflect.enum_field_names(allocation_type)

	file_info, err := os.stat(file)
	assert(err == nil, "failed to get file stats")
	size := int(file_info.size)

	arena: vmem.Arena
	arena_err := vmem.arena_init_static(&arena, uint(size))
	assert(arena_err == .None)
	arena_allocator := vmem.arena_allocator(&arena)

	buf := make([]byte, size, arena_allocator)
	cpu_freq := get_CPU_Freq()

	if infinite {
		for {
			for name in names {

				a: allocation_type
				switch (name) {
				case "NONE":
					a = .NONE
				case "ALLOC":
					a = .ALLOC
				}

				for test in tests {
					fmt.printfln("Test : %s + %s", test.label, name)
					tester := initialize_tester(size, a, buf, cpu_freq)
					test.func(&tester, file)
				}
			}
		}
	} else {
		for name in names {

			a: allocation_type
			switch (name) {
			case "NONE":
				a = .NONE
			case "ALLOC":
				a = .ALLOC
			}

			for test in tests {
				fmt.printfln("Test : %s + %s", test.label, name)
				tester := initialize_tester(size, a, buf, cpu_freq)
				test.func(&tester, file)
			}
		}
	}
}

read_via_readfile :: proc(tester: ^repetition_tester, file_name: string) {
	for is_testing(tester^) {
		file_handle, miss := os.open(file_name)
		assert(miss == nil, "failed to open the file")
		defer os.close(file_handle)

		handle_allocation(tester)

		begin_time(tester)
		byte_size, err := os.read(file_handle, tester.dest_buffer)
		tester.process_byte_count = byte_size
		end_time(tester)
		assert(err == nil, "failed to read the file")

		handle_deallocation(tester)
	}

	print_results(tester^)
}

read_entire_file_with_libc :: proc(tester: ^repetition_tester, file_name: string) {
	for is_testing(tester^) {
		filename := fmt.ctprint(file_name)

		f := libc.fopen(filename, "rb")
		assert(f != nil, "via fread: fopen failed")
		defer libc.fclose(f)

		handle_allocation(tester)

		begin_time(tester)
		result := libc.fread(raw_data(tester.dest_buffer), len(tester.dest_buffer), 1, f)
		tester.process_byte_count = len(tester.dest_buffer)
		end_time(tester)
		assert(result == 1, "via fread: fread failed")

		handle_deallocation(tester)
	}

	print_results(tester^)
}
