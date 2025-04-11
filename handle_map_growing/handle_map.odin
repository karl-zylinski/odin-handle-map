/* Handle-based map using growing virtual arena. By Karl Zylinski (karl@zylinski.se)

The Handle_Map maps a handle to an item. A handle consists of an index and a
generation. The item can be any type. Such a handle can be stored as a permanent
reference, where you'd usually store a pointer. The benefit of storing handles
instead of pointers is that you know if a slot has been reused, thanks to the
generation number. This makes it much easier to several systems to work with,
and store references to the items in the handle map.

This implementation stores an array of pointers to items. Those items are
allocated into a virtual growing arena. They'll never move within the virtual
growing arena, so pointers are stable.

Example (assumes this package is imported under the alias `hm`):

	Entity_Handle :: hm.Handle

	Entity :: struct {
		// All items must contain a handle
		handle: Entity_Handle,
		pos: [2]f32,
	}

	// You can also use
	// `entities := hm.make(Entity, Entity_Handle, min_items_per_block = 2048)`
	// if you want to tweak the arena block size.
	entities: hm.Handle_Map(Entity, Entity_Handle)

	h1 := hm.add(&entities, Entity { pos = { 5, 7 } })
	h2 := hm.add(&entities, Entity { pos = { 10, 5 } })

	// Resolve handle -> pointer
	if h2e := hm.get(entities, h2); h2e != nil {
		h2e.pos.y = 123
	}

	// Will remove this entity, leaving an unused slot
	hm.remove(&entities, h1)

	// Will reuse the slot h1 used
	h3 := hm.add(&entities, Entity { pos = { 1, 2 } })

	// Iterate. You can also use `for e in hm.items {}` and
	// skip any item where `e.handle.idx == 0`. The iterator
	// does that automatically.
	ent_iter := hm.make_iter(&entities)
	for e, h in hm.iter(&ent_iter) {
		e.pos += { 5, 1 }
	}

	hm.delete(&entities)
*/
package handle_map_growing

import "base:runtime"
import "base:builtin"

// Returned from the `add` proc. Store these as permanent references to items in
// the handle map. You can resolve the handle to a pointer using the `get` proc.
Handle :: struct {
	// index into `items` array of the `Handle_Map` struct.
	idx: u32,

	// When using the `get` proc, this will be matched to the `gen` on the item
	// in the handle map. The handle is only valid if they match. If they don't
	// match, then it means that the slot in the handle map has been reused.
	gen: u32,
}

Handle_Map :: struct($T: typeid, $HT: typeid) {
	// Each item in this array is allocated using `items_arena`. This array is
	// allocated using `context.allocator`, not using the arena. Only the items
	// themselves are allocated using `items_arena`.
	//
	// Each item much have a field `handle` of type `HT`.
	//
	// There's always a "dummy element" at index 0. This way, a Handle with
	// `idx == 0` means "no Handle".
	items: [dynamic]^T,

	// Arena that stores the data for each of the items. Since all of them are
	// allocated linearly into this arena, it means they are fairly well packed.
	// This gives stable pointers combined with good performance.
	//
	// Uses a Growing Virtual Arena on non-web platforms. On web platforms a
	// Dynamic Arena is used. See `arena_default.odin` and `arena_js.odin`
	items_arena: Arena,

	// The index into `items` of unused slots. `remove` will add things to it.
	unused_items: [dynamic]u32,
}

// Create a `Handle_Map` for the given item type `T` and handle type `HT`. The
// handle type should usually be defined as
//     Handle_Type :: distinct Handle
//
// `min_items_per_block` says how many items the underlying arena can store in
// each block of memory. Note that some platforms use a virtual arena, which
// has the minimum block size 4096 (a single memory page). So the block size
// will be `4096` if `min_items_per_block * size_of(T) < 4096`
//
// `allocator` specifies which allocator to use for the `items` and `unused_items`
// arrays. It will also be used on web builds for the Dynamic_Arena used on
// that platform.
make :: proc(
	$T: typeid,
	$HT: typeid,
	min_items_per_block: int = (ARENA_DEFAULT_BLOCK_SIZE/size_of(T)),
	allocator := context.allocator,
	loc := #caller_location) -> (res: Handle_Map(T, HT), err: runtime.Allocator_Error) #optional_allocator_error {
	m := Handle_Map(T, HT) {
		items = runtime.make([dynamic]^T, allocator, loc),
		unused_items = runtime.make([dynamic]u32, allocator, loc),
	}

	arena_init(&m.items_arena, min_items_per_block*size_of(T), allocator) or_return
	return m, nil
}

// Deallocate all memory associated with the Handle_Map.
delete :: proc(m: ^Handle_Map($T, $HT), loc := #caller_location) {
	arena_destroy(&m.items_arena)
	runtime.delete(m.items, loc)
	runtime.delete(m.unused_items, loc)
}

// Empties the handle map without deallocating all memory. The `items_arena` is
// deallocated, except the first block, since that one will be reused. `items`
// and `unused_items` are cleared, but not deallocated.
clear :: proc(m: ^Handle_Map($T, $HT), loc := #caller_location) {
	arena_free_all(&m.items_arena)
	runtime.clear(&m.items)
	runtime.clear(&m.unused_items)
}

// Add a value of type `T` to the handle map. Returns a handle you can use as a
// permanent reference.
//
// New items are allocated using an arena allocator, into the Handle_Map's
// `items_arena`. This makes pointers stable while giving good performance, due
// to the items being packed in the arena.
//
// Will reuse slots from `unused_items` array if there are any.
add :: proc(m: ^Handle_Map($T, $HT), v: T, loc := #caller_location) -> (res: HT, err: runtime.Allocator_Error) #optional_allocator_error {
	if !arena_initialized(m.items_arena) {
		m^ = make(T, HT, loc = loc) or_return
	}

	v := v

	if builtin.len(m.unused_items) > 0 {
		reuse_idx := pop(&m.unused_items)
		reused := m.items[reuse_idx]
		gen := reused.handle.gen
		reused^ = v
		reused.handle.idx = u32(reuse_idx)
		reused.handle.gen = gen + 1
		return reused.handle, nil
	}

	items_allocator := arena_allocator(&m.items_arena)

	if builtin.len(m.items) == 0 {
		zero_dummy := new(T, items_allocator) or_return
		append(&m.items, zero_dummy)
	}

	new_item := new(T, items_allocator) or_return
	new_item^ = v
	new_item.handle.idx = u32(builtin.len(m.items))
	new_item.handle.gen = 1
	append(&m.items, new_item)
	return new_item.handle, nil
}

// Resolve a handle to a pointer of type `^T`. The pointer is stable due to
// being allocated on the `items_arena`. But you should _not_ store the pointer
// permanently. The item may get reused if any part of your program destroys and
// reuses that slot. Only store handles permanently and temporarily resolve them
// into pointers as needed.
get :: proc(m: Handle_Map($T, $HT), h: HT) -> ^T {
	if h.idx <= 0 || h.idx >= u32(builtin.len(m.items)) {
		return nil
	}

	if item := m.items[h.idx]; item.handle == h {
		return item
	}

	return nil
}

// Remove an item from the handle map. You choose which item by passing a handle
// to this proc. The item is not really destroyed, rather its index is just
// added to the `unused_items` array. `handle.idx` on the item is set to zero,
// this is used by the `iter` proc in order to skip that item when iterating.
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

// Tells you if a handle maps to a valid item.
valid :: proc(m: Handle_Map($T, $HT), h: HT) -> bool {
	return get(m, h) != nil
}

// Tells you how many valid items there are in the handle map. Note how this
// is implemented: `1` is always subtracted from the total number, because there
// may be an item at index `0`. That item is not used, it's just there to make
// sure that `idx == 0` on a handle doesn't map to anything.
len :: proc(m: Handle_Map($T, $HT)) -> int {
	return max(builtin.len(m.items), 1) - builtin.len(m.unused_items) - 1
}

// For iterating a handle map. Create using `make_iter`.
Handle_Map_Iterator :: struct($T: typeid, $HT: typeid) {
	m: ^Handle_Map(T, HT),
	index: int,
}

// Create an iterator. Use with `iter` to do the actual iteration.
make_iter :: proc(m: ^Handle_Map($T, $HT)) -> Handle_Map_Iterator(T, HT) {
	return { m = m }
}

// Iterate over the handle map. Skips unused slots, meaning that it skips slots
// with handle.idx == 0.
//
// Usage:
//     my_iter := hm.make_iter(&my_handle_map)
//     for e in hm.iter(&my_iter) {}
// 
// Instead of using an iterator you can also loop over `items` and check if
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

// If you don't want to use iterator, you can instead do:
// for &item in my_map.items {
//     if hm.skip(item) {
//         continue
//     }
//     // do stuff
// }
skip :: proc(e: $T) -> bool {
	return e.handle.idx == 0
}