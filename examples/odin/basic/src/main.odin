package main

import "core:fmt"

show_count :: proc(value: int) {
	fmt.println("count=", value)
}

show_item :: proc(value: string) {
	fmt.println("item=", value)
}

show :: proc{show_count, show_item}

main :: proc() {
	numbers := make([dynamic]int, 0, 4)
	defer delete(numbers)

	append(&numbers, 3)
	append(&numbers, 5)
	append(&numbers, 8)
	fmt.println("dynamic array:", numbers[:])

	scores := make(map[string]int)
	defer delete(scores)

	scores["odin"] = 3
	scores["nim"] = 2
	scores["zig"] = 1

	fmt.println("hashmap entries:")
	for name, value in scores {
		fmt.println("  ", name, " -> ", value)
	}

	fmt.println("proc group calls:")
	show(len(numbers))
	show("odin")
}
