package handle_map_example

import hm "../../handle_map_static"
import rl "vendor:raylib"
import "core:time"
import "core:math/rand"
import "core:fmt"

Entity :: struct {
	handle: Entity_Handle,
	id: int,
}

Entity_Handle :: distinct hm.Handle
MAX_ENTITIES :: 3
entities: hm.Handle_Map(Entity, Entity_Handle, MAX_ENTITIES)
player: Entity_Handle
entity_add_at: time.Time

main :: proc() {
	count := 0
	handles := [MAX_ENTITIES]Entity_Handle{}
	for i in 0..<MAX_ENTITIES {
		handle := hm.add(&entities, Entity{
			id = count
		})
		handles[i] = handle
		count += 1
	}
	{
		e_0 := hm.get(&entities, handles[0]); assert(e_0.id == 0, "Expected id == 0")
		e_1 := hm.get(&entities, handles[1]); assert(e_1.id == 1, "Expected id == 1")
		e_2 := hm.get(&entities, handles[2]); assert(e_2.id == 2, "Expected id == 2")
	}
	assert(hm.valid(entities, handles[0]) == true, "The test entity expected to be valid.")
	for i in 0..<MAX_ENTITIES {
		hm.remove(&entities, handles[i])
	}
	assert(hm.valid(entities, handles[0]) == false, "The test entity expected to be invalid.")

	for i in 0..<MAX_ENTITIES {
		handle2 := hm.add(&entities, Entity{
			id = count
		})
		assert(hm.valid(entities, handles[i]) == false, "The previously deleted test entity expected to be invalid")
		handles[i] = handle2
		count += 1
	}
	assert(hm.valid(entities, handles[0]) == true, "The test entity is expected to be valid.")
	{
		e_0 := hm.get(&entities, handles[0]); assert(e_0.id == 3, "Expected id == 3")
		e_1 := hm.get(&entities, handles[1]); assert(e_1.id == 4, "Expected id == 4")
		e_2 := hm.get(&entities, handles[2]); assert(e_2.id == 5, "Expected id == 5")
	}

	fmt.printfln("All good")
}
