package handle_map

import "core:log"

test :: proc() {
	Entity :: struct {
		handle: Entity_Handle,
		pos: [2]f32,
		vel: [2]f32,
	}

	Entity_Handle :: distinct Handle

	m: Handle_Map(Entity, Entity_Handle)
	h1 := add(&m, Entity {pos = {1, 2}})
	h2 := add(&m, Entity {pos = {2, 2}})
	h3 := add(&m, Entity {pos = {3, 2}})

	assert(h1.idx == 1)
	assert(h2.idx == 2)
	assert(h3.idx == 3)

	remove(&m, h2)

	// This one will reuse the slot h2 had
	h4 := add(&m, Entity {pos = {4, 2}})

	assert(h1.gen == 1)
	assert(h2.gen == 1)
	assert(h3.gen == 1)

	if _, ok := get(m, h2); ok {
		panic("h2 should not be valid")
	}

	if h4_ptr := get_ptr(m, h4); h4_ptr != nil {
		assert(h4_ptr.pos == {4, 2})
		h4_ptr.pos = {5, 2}
	} else {
		panic("h4 should be valid")
	}

	if h4_val, ok := get(m, h4); ok {
		assert(h4_val.pos == {5, 2})
	} else {
		panic("h4 should be valid")
	}

	remove(&m, h4)
	h5 := add(&m, Entity {pos = {6, 2}})
	assert(h5.idx == 4)

	destroy(&m)
}