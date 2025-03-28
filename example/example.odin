package handle_map_example

import hm "../handle_map"
import rl "vendor:raylib"
import "core:time"
import "core:math/rand"
import "core:fmt"

Entity :: struct {
	handle: Entity_Handle,
	pos: [2]f32,
	size: f32,
	color: rl.Color,
}

Entity_Handle :: distinct hm.Handle
entities: hm.Handle_Map(Entity, Entity_Handle)
player: Entity_Handle
entity_add_at: time.Time

main :: proc() {
	rl.InitWindow(1280, 720, "Entities using Handle Map")

	player = hm.add(&entities, Entity {
		size = 30,
		color = rl.BLACK,
	})

	for !rl.WindowShouldClose() {
		update()
		draw()
		free_all(context.temp_allocator)
	}

	hm.delete(&entities)
	rl.CloseWindow()
}

update :: proc() {
	p := hm.get(entities, player)
	assert(p != nil, "Couldn't get player pointer")
	p.pos = rl.GetMousePosition()

	if p.size >= 5 {
		p.size -= rl.GetFrameTime() * 5
	}

	ent_iter := hm.make_iter(&entities)
	for e, h in hm.iter(&ent_iter) {
		if h == player {
			continue
		}

		if rl.CheckCollisionCircles(p.pos, p.size, e.pos, e.size) {
			p.size += e.size * 0.1
			hm.remove(&entities, h)
		}
	}

	if time.duration_seconds(time.since(entity_add_at)) > 0.2 {
		size := rand.float32_range(5, 35)
		hm.add(&entities, Entity {
			pos = {
				rand.float32_range(size + 5, f32(rl.GetScreenWidth()) - size - 5),
				rand.float32_range(size + 5, f32(rl.GetScreenHeight()) - size - 5),
			},
			size = size,
			color = {
				u8(rand.int_max(128) + 127),
				u8(rand.int_max(128) + 127),
				u8(rand.int_max(128) + 127),
				255,
			},
		})

		entity_add_at = time.now()
	}
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLUE)

	ent_iter := hm.make_iter(&entities)
	for e, h in hm.iter(&ent_iter) {
		if h == player {
			continue
		}

		rl.DrawCircleV(e.pos, e.size, e.color)
	}

	if p := hm.get(entities, player); p != nil {
		rl.DrawCircleV(p.pos, p.size, p.color)
	}

	TEXT_SIZE :: 28
	rl.DrawText("entities stats", 5, 5, TEXT_SIZE, rl.BLACK)
	rl.DrawText(fmt.ctprintf("len: %v", hm.len(entities)), 5, 5 + TEXT_SIZE, TEXT_SIZE, rl.BLACK)
	rl.DrawText(fmt.ctprintf("unused slots: %v", len(entities.unused_items)), 5, 5 + TEXT_SIZE*2, TEXT_SIZE, rl.BLACK)
	rl.DrawText(fmt.ctprintf("items arena reserved: %v", entities.items_arena.total_reserved), 5, 5 + TEXT_SIZE*3, TEXT_SIZE, rl.BLACK)
	rl.DrawText(fmt.ctprintf("items arena used: %v", entities.items_arena.total_used), 5, 5 + TEXT_SIZE*4, TEXT_SIZE, rl.BLACK)

	rl.EndDrawing()
}
