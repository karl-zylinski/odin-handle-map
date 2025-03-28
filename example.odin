package handle_map_example

import hm "handle_map"
import "core:fmt"
import "core:math/rand"
import "core:time"
import "core:math/linalg"

Entity :: struct {
	handle: Entity_Handle,
	pos: [3]f32,
}

Entity_Handle :: distinct hm.Handle

NUM_ENTITIES :: 100000

main :: proc() {
	m := hm.make(Entity, Entity_Handle)

	comparison_array := make([]Entity, NUM_ENTITIES)

	for i in 0..<NUM_ENTITIES {
		e := Entity {
			pos = { rand.float32_range(-100, 100), rand.float32_range(-100, 100), rand.float32_range(-100, 100) },
		}
		hm.add(&m, e)
		comparison_array[i] = e
	}

	assert(hm.len(m) == NUM_ENTITIES)
	assert(hm.len(m) == len(comparison_array))

	for _ in 0..<100000 {
		idx := rand.int_max(hm.len(m))
		hm.remove(&m, Entity_Handle { u32(idx), 1 } )
	}

	NUM_TESTS :: 100

	{
		nearest_to_origin: [3]f32
		nearest_to_origin_dist := max(f32)
		fmt.println("handle map")
		start := time.now()
		for _ in 0..<NUM_TESTS {
			iter := hm.make_iter(&m)
			for e in hm.iter(&iter) {
				if linalg.length(e.pos) < nearest_to_origin_dist {
					nearest_to_origin = e.pos
				}

				for _ in 0..<10 {
					e.pos.x += 0.1
				}
			}
		}
		diff := time.since(start)

		fmt.println(time.duration_milliseconds(diff))
		fmt.println(nearest_to_origin)
	}

	{
		nearest_to_origin: [3]f32
		nearest_to_origin_dist := max(f32)
		fmt.println("fixed size slice")
		start := time.now()
		for _ in 0..<NUM_TESTS {
			for &e in comparison_array {
				if linalg.length(e.pos) < nearest_to_origin_dist {
					nearest_to_origin = e.pos
				}

				for _ in 0..<10 {
					e.pos.x += 0.1
				}
			}
		}
		diff := time.since(start)

		fmt.println(time.duration_milliseconds(diff))
		fmt.println(nearest_to_origin)
	}
}