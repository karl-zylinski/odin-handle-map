package handle_map

import "base:runtime"
import "base:builtin"
import "core:fmt"
import vmem "core:mem/virtual"

_ :: fmt

Handle :: struct {
	idx: u32,
	gen: u32,
}

HANDLE_NONE :: Handle {}

Handle_Map :: struct($T: typeid, $HT: typeid) {
	items: [dynamic]^T,
	items_arena: vmem.Arena,
	unused_items: [dynamic]u32,
}

delete :: proc(m: ^Handle_Map($T, $HT), loc := #caller_location) {
	vmem.arena_destroy(&m.items_arena)
	runtime.delete(m.items, loc)
	runtime.delete(m.unused_items, loc)
}

clear :: proc(m: ^Handle_Map($T, $HT), loc := #caller_location) {
	vmem.arena_free_all(&m.items_arena)
	runtime.clear(&m.items)
	runtime.clear(&m.unused_items)
}

DEFAULT_MIN_ITEMS_PER_BLOCK :: 1024

make :: proc($T: typeid, $HT: typeid, min_items_per_block := DEFAULT_MIN_ITEMS_PER_BLOCK, allocator := context.allocator, loc := #caller_location) -> Handle_Map(T, HT) {
	m := Handle_Map(T, HT) {
		items = runtime.make([dynamic]^T, allocator, loc),
		unused_items = runtime.make([dynamic]u32, allocator, loc),
	}

	err := vmem.arena_init_growing(&m.items_arena, uint(min_items_per_block * size_of(T)))
	fmt.ensuref(err == nil, "Error initializing arena: %v", err)
	return m
}

add :: proc(m: ^Handle_Map($T, $HT), v: T, loc := #caller_location) -> HT {
	if m.items_arena.curr_block == nil {
		m^ = make(T, HT, loc = loc)
	}

	v := v

	if builtin.len(m.unused_items) > 0 {
		reuse_idx := pop(&m.unused_items)
		reused := m.items[reuse_idx]
		gen := reused.handle.gen
		reused^ = v
		reused.handle.idx = u32(reuse_idx)
		reused.handle.gen = gen + 1
		return reused.handle
	}

	items_allocator := vmem.arena_allocator(&m.items_arena)

	if builtin.len(m.items) == 0 {
		zero_dummy := new(T, items_allocator)
		append(&m.items, zero_dummy)
	}

	new_item := new(T, items_allocator)
	new_item^ = v
	new_item.handle.idx = u32(builtin.len(m.items))
	new_item.handle.gen = 1
	append(&m.items, new_item)
	return new_item.handle 
}

get :: proc(m: Handle_Map($T, $HT), h: HT) -> ^T {
	if h.idx <= 0 || h.idx >= u32(builtin.len(m.items)) {
		return nil
	}

	if item := m.items[h.idx]; item.handle == h {
		return item
	}

	return nil
}

remove :: proc(m: ^Handle_Map($T, $HT), h: HT) {
	if h.idx <= 0 || h.idx >= u32(builtin.len(m.items)) {
		return
	}

	if item := m.items[h.idx]; item.handle == h {
		append(&m.unused_items, h.idx)

		// This makes the item invalid. `iter` uses that to skip over it.
		// We'll set the index back if the slot is reused.
		item.handle.idx = 0
	}
}

valid :: proc(m: Handle_Map($T, $HT), h: HT) -> bool {
	return get_ptr(m, h) != nil
}

len :: proc(m: Handle_Map($T, $HT)) -> int {
	return max(builtin.len(m.items), 1) - builtin.len(m.unused_items) - 1
}

Handle_Map_Iterator :: struct($T: typeid, $HT: typeid) {
	m: ^Handle_Map(T, HT),
	index: int,
}

make_iter :: proc(m: ^Handle_Map($T, $HT)) -> Handle_Map_Iterator(T, HT) {
	return { m = m }
}

// Instead of using iterator you can also loop over `items` and check if
// `item.handle.idx == 0` and in that case skip that item.
iter :: proc(it: ^Handle_Map_Iterator($T, $HT)) -> (val: ^T, h: HT, cond: bool) {
	for _ in it.index..<builtin.len(it.m.items) {
		item := it.m.items[it.index]
		it.index += 1

		if item.handle.idx != 0 {
			return item, item.handle, true
		}
	}

	return nil, {}, false
}
