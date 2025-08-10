package tester

import "core:fmt"
import "core:mem"
import "core:os"
import "core:simd/x86"
import "core:time"

Test :: struct {
	label: string,
	func:  proc(tester: ^repetition_tester, file_name: string),
}

tests := [?]Test {
	{label = "read_entire_file_from_filename", func = read_entire_file_with_filename_test},
	{label = "read_entire_file_from_handle_or_err", func = read_entire_file_with_filename_test},
}

main :: proc() {
	file := "../listing_0101_read_bandwidth_main/haversine/data.json"

	for test in tests {
		fmt.printfln("Test : %s", test.label)
		tester := initialize_tester(file)

		test.func(&tester, file)
	}
}

read_entire_file_with_filename_test :: proc(tester: ^repetition_tester, file_name: string) {
	for is_testing(tester^) {

		begin_time(tester)

		data, ok := os.read_entire_file_from_filename(
			"../listing_0101_read_bandwidth_main/haversine/data.json",
		)

		tester.process_byte_count = len(data)
		end_time(tester)

		assert(ok, "failed to read the file")
		delete(data, context.allocator)

	}
	print_results(tester^)
}

read_entire_file_with_handle_test :: proc(tester: ^repetition_tester, file_name: string) {
	for is_testing(tester^) {

		file_handle, miss := os.open(file_name)
		assert(miss == nil, "failed to open the file")
		defer os.close(file_handle)

		begin_time(tester)

		data, err := os.read_entire_file_from_handle_or_err(file_handle)
		tester.process_byte_count = len(data)

		end_time(tester)

		assert(err == nil, "failed to read the file")
		delete(data, context.allocator)

	}
	print_results(tester^)
}
