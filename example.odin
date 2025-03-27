package handle_map_example

import hm "handle_map"
import "core:fmt"

Entity :: struct {
	handle: Entity_Handle,
	pos: [2]f32,
	vel: [2]f32,
}

Entity_Handle :: distinct hm.Handle

main :: proc() {
	m: hm.Handle_Map(Entity, Entity_Handle)
	h1 := hm.add(&m, Entity { pos = {2, 1} })
	h2 := hm.add(&m, Entity { pos = {3, 1} })

	assert(h1.idx == 1)
	assert(h2.idx == 2)
	hm.remove(&m, h1)

	h3 := hm.add(&m, Entity { pos = {4,1 }})
	assert(h3.idx == 1)

	m_iter := hm.make_iter(&m)

	for e in hm.iter_ptr(&m_iter) {
		fmt.println(e.pos)
	}

	h1e := hm.get(m, h1)

	for i in 0..<10000 {
		hm.add(&m, Entity { pos = {f32(i), f32(i*i)} })
	}

	assert(h1e == hm.get(m, h1))

	fmt.println(hm.len(m))

	s := size_of(Entity)
	prev_ptr: ^Entity
	idx := 0

	m_iter = hm.make_iter(&m)
	for e in hm.iter_ptr(&m_iter) {
		if prev_ptr != nil {
			distance_to_prev := uintptr(e) - uintptr(prev_ptr)
			if int(distance_to_prev) != s {
				fmt.printfln("hop %v", idx)
			}
		}

		prev_ptr = e

		idx += 1
	}
}