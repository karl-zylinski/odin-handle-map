package handle_map

import "core:fmt"
import "core:mem"
import "core:slice"
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
	zero_item: T,
}

destroy :: proc(m: ^Handle_Map($T, $HT), loc := #caller_location) {
	vmem.arena_destroy(&m.items_arena)
	delete(m.items, loc)
	delete(m.unused_items, loc)
}

clear :: proc(m: ^Handle_Map($T, $HT), loc := #caller_location) {
	vmem.arena_free_all(&m.items_arena)
	clear(&m.items)
	clear(&m.unused_items)
}

make_handle_map :: proc($T: typeid, $HT: typeid, allocator: mem.Allocator, loc := #caller_location) -> Handle_Map(T, HT) {
	return {
		items = make([dynamic]T, allocator, loc),
		unused_items = make([dynamic]u32, allocator, loc)
	}
}

add :: proc(m: ^Handle_Map($T, $HT), v: T, loc := #caller_location) -> HT {
	if m.items == nil {
		m.items = make([dynamic]^T, context.allocator, loc)
		m.unused_items = make([dynamic]u32, context.allocator, loc)
	}

	v := v

	if len(m.unused_items) > 0 {
		reuse_idx := pop(&m.unused_items)
		reused := m.items[reuse_idx]
		h := reused.handle
		reused^ = v
		reused.handle.idx = u32(reuse_idx)
		reused.handle.gen = h.gen + 1
		return reused.handle
	}

	items_allocator := vmem.arena_allocator(&m.items_arena)

	if len(m.items) == 0 {
		zero_dummy := new(T, items_allocator)
		append(&m.items, zero_dummy)
	}

	new_item := new(T, items_allocator)
	new_item^ = v
	new_item.handle.idx = u32(len(m.items))
	new_item.handle.gen = 1
	append(&m.items, new_item)
	return new_item.handle
}

get :: proc(m: Handle_Map($T, $HT), h: HT) -> (T, bool) #optional_ok {
	if ptr := get_ptr(m, h); ptr != nil {
		return ptr^, true
	}

	return {}, false
}

get_ptr :: proc(m: Handle_Map($T, $HT), h: HT) -> ^T {
	if h.idx <= 0 || h.idx >= u32(len(m.items)) {
		return nil
	}

	if item := m.items[h.idx]; item.handle == h {
		return item
	}

	return nil
}

remove :: proc(m: ^Handle_Map($T, $HT), h: HT) {
	if h.idx <= 0 || h.idx >= u32(len(m.items)) {
		return
	}

	if item := m.items[h.idx]; item.handle == h {
		append(&m.unused_items, h.idx)

		// This makes the item invalid. We'll set the index back if the slot is reused.
		item.handle.idx = 0
	}
}

valid :: proc(m: Handle_Map($T, $HT), h: HT) -> bool {
	return get_ptr(m, h) != nil
}

Handle_Map_Iterator :: struct($T: typeid, $HT: typeid) {
	m: ^Handle_Map(T, HT),
	index: int,
}

make_iter :: proc(m: ^Handle_Map($T, $HT)) -> Handle_Map_Iterator(T, HT) {
	return { m = m }
}

iter :: proc(it: ^Handle_Map_Iterator($T, $HT)) -> (val: T, h: HT, cond: bool) {
	val_ptr: ^T

	val_ptr, h, cond = iter_ptr(it)

	if val_ptr != nil {
		val = val_ptr^
	}

	return
}

iter_ptr :: proc(it: ^Handle_Map_Iterator($T, $HT)) -> (val: ^T, h: HT, cond: bool) {
	cond = it.index < len(it.m.items)

	for ; cond; cond = it.index < len(it.m.items) {
		if it.m.items[it.index].handle.idx == 0 {
			it.index += 1
			continue
		}

		val = &it.m.items[it.index]
		h = val.handle
		it.index += 1
		break
	}

	return
}
