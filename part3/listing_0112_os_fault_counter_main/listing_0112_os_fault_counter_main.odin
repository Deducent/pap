package tester

import "core:fmt"
import vmem "core:mem/virtual"
import "core:os"
import "core:strconv"
import "core:sys/linux"

get_page_fault :: proc() -> int {
	usage: linux.RUsage
	err_code := linux.getrusage(.SELF, &usage)
	assert(err_code == .NONE, fmt.tprintfln("Error code for start: %v", err_code))
	return usage.minflt_word + usage.majflt_word
}

main :: proc() {
	assert(len(os.args) == 2, "pass in page count as a number")
	page_count, ok := strconv.parse_uint(os.args[1])
	assert(ok, "not a number")
	// page_count := uint(2)
	page_size := vmem.DEFAULT_PAGE_SIZE
	total_size := page_count * page_size

	arena: vmem.Arena
	err := vmem.arena_init_static(&arena, total_size)
	assert(err == .None, "could allocate memory")
	arena_allocator := vmem.arena_allocator(&arena)

	buf := make([]u8, total_size)

	fmt.println("Page Count, Touch Count, Fault Count, Extra Faults")

	for count in 0 ..< page_count {
		page := count * page_size

		start_fault_count := get_page_fault()
		touch_one_page: for i := uint(0); i < page_size; i += 1 {
			buf[page + i] = u8(i)
		}
		end_fault_count := get_page_fault()

		fault_count := end_fault_count - start_fault_count

		extra_faults := fault_count - int(count)

		if extra_faults < 0 {
			extra_faults = 0
		}

		fmt.printfln("%v, %v, %v, %v", page, count, fault_count, extra_faults)
	}
}
