package handle_map_performance_comparison

import hms "../handle_map_static"
import hmv "../handle_map_static_virtual"
import hmg "../handle_map_growing"
import "core:fmt"
import "core:math/rand"
import "core:time"

main :: proc() {
	benchmark_static()
	benchmark_static_virtual()
	benchmark_growing()
}

// Doesn't matter if it's Handle type from hmv, hmg or hmv. They are all the same.
Entity_Handle :: distinct hmv.Handle

Entity :: struct {
	handle: Entity_Handle,
	pos: [2]f32,
	age: int,

	/* Read this if you want to try SoA layout for the handle_map_static package

	Try un-commenting the `extra_data` line below and then change the
	following in `../handle_map_static/handle_map.odin`:
	`items: [N]T,` --> `items: #soa [N]T`

	Also change the loop in `benchmark_static` that uses `ent_iter`, so it instead
	looks like this:
	
		for &e in static_entities {
			if hms.skip(e) { continue }
			// the original contents of the loop
		}

	Note: You can't easily change the other implementations to SoA. Also note
	that not all programs may have this big amount of "extra data". */

	// extra_data: [512]byte,
}

NUM_ENTITIES :: 100000
NUM_TESTS :: 100

// This is not in `benchmark_static` because it would blow the stack of that proc.
static_entities: hms.Handle_Map(Entity, Entity_Handle, NUM_ENTITIES)

benchmark_static :: proc() {
	for _ in 0..<NUM_ENTITIES-1 {
		e := Entity {
			pos = {
				rand.float32_range(-100, 100),
				rand.float32_range(-100, 100),
			},
			age = rand.int_max(98) + 1,
		}

		hms.add(&static_entities, e)
	}

	age_total: int
	start := time.now()
	for _ in 0..<NUM_TESTS {
		ent_iter := hms.make_iter(&static_entities)
		for e in hms.iter(&ent_iter) {
			e.pos += { 5, 1 }
			age_total += e.age
		}
	}
	diff := time.since(start)
	fmt.printfln("Average age: %v", age_total / (NUM_ENTITIES * NUM_TESTS))
	fmt.printfln("Fixed Handle_Map: %.3f ms", time.duration_milliseconds(diff))
}

benchmark_static_virtual :: proc() {
	entities: hmv.Handle_Map(Entity, Entity_Handle, NUM_ENTITIES)

	for _ in 0..<NUM_ENTITIES-1 {
		e := Entity {
			pos = {
				rand.float32_range(-100, 100),
				rand.float32_range(-100, 100),
			},
			age = rand.int_max(98) + 1,
		}

		hmv.add(&entities, e)
	}

	age_total: int
	start := time.now()
	for _ in 0..<NUM_TESTS {
		ent_iter := hmv.make_iter(&entities)
		for e in hmv.iter(&ent_iter) {
			e.pos += { 5, 1 }
			age_total += e.age
		}
	}
	diff := time.since(start)
	fmt.printfln("Average age: %v", age_total / (NUM_ENTITIES * NUM_TESTS))
	fmt.printfln("Virtual Handle_Map: %.3f ms", time.duration_milliseconds(diff))
}

benchmark_growing :: proc() {
	entities: hmg.Handle_Map(Entity, Entity_Handle)

	for _ in 0..<NUM_ENTITIES-1 {
		e := Entity {
			pos = {
				rand.float32_range(-100, 100),
				rand.float32_range(-100, 100),
			},
			age = rand.int_max(101),
		}

		hmg.add(&entities, e)
	}

	age_total: int
	start := time.now()
	for _ in 0..<NUM_TESTS {
		ent_iter := hmg.make_iter(&entities)
		for e in hmg.iter(&ent_iter) {
			e.pos += { 5, 1 }
			age_total += e.age
		}
	}
	diff := time.since(start)
	fmt.printfln("Average age: %v", age_total / (NUM_ENTITIES * NUM_TESTS))
	fmt.printfln("Generic Handle_Map: %.3f ms", time.duration_milliseconds(diff))
}
