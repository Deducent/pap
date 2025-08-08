package tester

import "core:fmt"
import "core:mem"
import "core:os"
import "core:simd/x86"
import "core:time"

main :: proc() {
	{
		tester := initialize_tester()

		data: []byte
		ok: bool

		for is_testing(tester) {

			begin_time(&tester)

			data, ok = os.read_entire_file_from_filename(
				"../listing_0101_read_bandwidth_main/haversine/data.json",
			)

			tester.process_byte_count = len(data)
			end_time(&tester)

			assert(ok, "failed to read the file")
			delete(data, context.allocator)

		}
		print_results(tester)
	}

	{
		tester := initialize_tester()

		data: []byte
		err: os.Error

		for is_testing(tester) {

			file_data, miss := os.open("../listing_0101_read_bandwidth_main/haversine/data.json")
			assert(miss == nil, "failed to open the file")
			defer os.close(file_data)

			begin_time(&tester)

			data, err = os.read_entire_file_from_handle_or_err(file_data)
			tester.process_byte_count = len(data)

			end_time(&tester)

			assert(err == nil, "failed to read the file")
			delete(data, context.allocator)

		}
		print_results(tester)
	}
}
