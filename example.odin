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

NUM_ENTITIES :: 1000

comparison_array: [NUM_ENTITIES]Entity

main :: proc() {
	m := hm.make(Entity, Entity_Handle, min_items_per_block = 2048)

	dynamic_comparison_array: [dynamic]Entity

	for i in 0..<NUM_ENTITIES {
		e := Entity { pos = { rand.float32_range(-100, 100), rand.float32_range(-100, 100), rand.float32_range(-100, 100) } }
		hm.add(&m, e)
		append(&dynamic_comparison_array, e)
		comparison_array[i] = e
	}


	NUM_TESTS :: 1000

	{
		nearest_to_origin: [3]f32
		nearest_to_origin_dist: f32 = max(f32)
		fmt.println("handle map")
		start := time.now()
		for _ in 0..<NUM_TESTS {
			iter := hm.make_iter(&m)
			for e in hm.iter(&iter) {
				if linalg.length(e.pos) < nearest_to_origin_dist {
					nearest_to_origin = e.pos
				}
			}
		}
		diff := time.since(start)

		fmt.println(time.duration_milliseconds(diff))
		fmt.println(nearest_to_origin)
	}

	{
		nearest_to_origin: [3]f32
		nearest_to_origin_dist: f32 = max(f32)
		fmt.println("dyn array")
		start := time.now()
		for _ in 0..<NUM_TESTS {
			for &e in dynamic_comparison_array {
				if linalg.length(e.pos) < nearest_to_origin_dist {
					nearest_to_origin = e.pos
				}
			}
		}
		diff := time.since(start)

		fmt.println(time.duration_milliseconds(diff))
		fmt.println(nearest_to_origin)
	}

	{
		nearest_to_origin: [3]f32
		nearest_to_origin_dist: f32 = max(f32)
		fmt.println("fixed array")
		start := time.now()
		for _ in 0..<NUM_TESTS {
			for &e in comparison_array {
				if linalg.length(e.pos) < nearest_to_origin_dist {
					nearest_to_origin = e.pos
				}
			}
		}
		diff := time.since(start)

		fmt.println(time.duration_milliseconds(diff))
		fmt.println(nearest_to_origin)
	}
}