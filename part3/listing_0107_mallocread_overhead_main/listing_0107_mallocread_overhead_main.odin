package tester

import "base:runtime"
import "core:c/libc"
import "core:fmt"
import "core:mem"
import vmem "core:mem/virtual"
import "core:os"
import "core:reflect"
import "core:simd/x86"
import "core:time"

Test :: struct {
	label: string,
	func:  proc(tester: ^repetition_tester, file_name: string),
}

tests := [?]Test {
	// {label = "read_entire_file_from_filename", func = read_entire_file_with_filename_test},
	// {label = "read_entire_file_from_handle_or_err", func = read_entire_file_with_filename_test},
	{label = "read_via_readfile", func = read_via_readfile},
	// {label = "read_entire_file_with_libc", func = read_entire_file_with_libc},
}

main :: proc() {
	file := "../listing_0101_read_bandwidth_main/haversine/data.json"
	infinite: bool

	// runtime.default_allocator()
	for arg in os.args {
		if arg == "--inf" {
			infinite = true
		}
	}

	names := reflect.enum_field_names(allocation_type)

	arena: vmem.Arena
	err := vmem.arena_init_static(&arena, 1 * mem.Gigabyte)
	assert(err == .None)
	arena_allocator := vmem.arena_allocator(&arena)

	if infinite {
		for {
			for test in tests {
				fmt.printfln("Test : %s", test.label)
				// tester := initialize_tester(file)

				// test.func(&tester, file)
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
				tester := initialize_tester(file, all_type = a)
				test.func(&tester, file)
			}
		}
	}
}

read_entire_file_with_filename_test :: proc(tester: ^repetition_tester, file_name: string) {
	for is_testing(tester^) {

		begin_time(tester)
		data, ok := os.read_entire_file_from_filename(file_name, context.allocator)
		tester.process_byte_count = len(data)
		end_time(tester)

		assert(ok, "failed to read the file")
		delete(data, context.allocator)

	}
	print_results(tester^)
}

// read_entire_file_with_handle_test :: proc(tester: ^repetition_tester, file_name: string) {
// 	for is_testing(tester^) {
//
// 		file_handle, miss := os.open(file_name)
// 		assert(miss == nil, "failed to open the file")
// 		defer os.close(file_handle)
//
// 		begin_time(tester)
// 		data, err := os.read_entire_file_from_handle_or_err(file_handle, context.allocator)
// 		tester.process_byte_count = len(data)
// 		end_time(tester)
//
// 		assert(err == nil, "failed to read the file")
// 		delete(data, context.allocator)
//
// 	}
// 	print_results(tester^)
// }

read_via_readfile :: proc(tester: ^repetition_tester, file_name: string) {
	for is_testing(tester^) {
		file_handle, miss := os.open(file_name)
		assert(miss == nil, "failed to open the file")
		defer os.close(file_handle)

		dest_buffer := make([]u8, tester.target_byte_count, context.temp_allocator)
		begin_time(tester)
		byte_size, err := os.read(file_handle, dest_buffer)
		tester.process_byte_count = byte_size
		end_time(tester)

		assert(err == nil, "failed to read the file")
		free_all(context.temp_allocator)
	}

	print_results(tester^)
}

read_entire_file_with_libc :: proc(tester: ^repetition_tester, file_name: string) {
	for is_testing(tester^) {
		filename := fmt.ctprint(file_name)

		f := libc.fopen(filename, "rb")
		assert(f != nil, "via fread: fopen failed")
		defer libc.fclose(f)

		dest_buffer := make([]u8, tester.target_byte_count, context.temp_allocator)

		begin_time(tester)
		result := libc.fread(raw_data(dest_buffer), len(dest_buffer), 1, f)
		tester.process_byte_count = len(dest_buffer)
		end_time(tester)

		assert(result == 1, "via fread: fread failed")
		free_all(context.temp_allocator)
	}

	print_results(tester^)
}
