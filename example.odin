package handle_map_example

import hm "handle_map"
import "core:fmt"
import "core:math/rand"
import "core:time"
import "core:math/linalg"

Entity :: struct {
	handle: Entity_Handle,
	mat: matrix[4, 4]f32,
}

Entity_Handle :: distinct hm.Handle

NUM_ENTITIES :: 1000

comparison_array: [NUM_ENTITIES]Entity

main :: proc() {
	m := hm.make(Entity, Entity_Handle, min_items_per_block = 2048)/*
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

	h1e := hm.get(m, h1)*/

	comp2: [dynamic]Entity

	for i in 0..<NUM_ENTITIES {
		rm := matrix[4,4]f32 {
			rand.float32_range(-1, 1), rand.float32_range(-1, 1), rand.float32_range(-1, 1), rand.float32_range(-1, 1),
			rand.float32_range(-1, 1), rand.float32_range(-1, 1), rand.float32_range(-1, 1), rand.float32_range(-1, 1),
			rand.float32_range(-1, 1), rand.float32_range(-1, 1), rand.float32_range(-1, 1), rand.float32_range(-1, 1),
			rand.float32_range(-1, 1), rand.float32_range(-1, 1), rand.float32_range(-1, 1), rand.float32_range(-1, 1),
		}

		e := Entity { mat = rm }
		hm.add(&m, e)
		append(&comp2, e)
		comparison_array[i] = e
	}


	NUM_TESTS :: 1000

	{
		total: f32
		fmt.println("handle map")
		start := time.now()
		for _ in 0..<NUM_TESTS {
			iter := hm.make_iter(&m)
			for e in hm.iter(&iter) {
				total += linalg.trace(linalg.inverse(e.mat))
			}
		}
		diff := time.since(start)

		fmt.println(time.duration_milliseconds(diff))
		fmt.println(total)
	}

	{
		total: f32
		fmt.println("dyn array")
		start := time.now()
		for _ in 0..<NUM_TESTS {
			for &e in comp2 {
				total += linalg.trace(linalg.inverse(e.mat))
			}
		}
		diff := time.since(start)

		fmt.println(time.duration_milliseconds(diff))
		fmt.println(total)
	}

	{
		total: f32
		fmt.println("fixed array")
		start := time.now()
		for _ in 0..<NUM_TESTS {
			for &e in comparison_array {
				total += linalg.trace(linalg.inverse(e.mat))
			}
		}
		diff := time.since(start)

		fmt.println(time.duration_milliseconds(diff))
		fmt.println(total)
	}
}