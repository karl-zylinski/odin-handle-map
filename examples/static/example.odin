/*
This is a small game where the player is a black circle and it can consume
other circles.

The circles live in a handle map. Each circle is an Entity.

The demo shows how to create, add, remove and iterate using the handle map.

See ../example_web for a version that works in a browser.
*/
package handle_map_example

import hm "../../handle_map_static"
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
entities: hm.Handle_Map(Entity, Entity_Handle, 1024)
player: Entity_Handle
entity_add_at: time.Time

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "Entities using Handle Map (fixed array)")

	reset()

	for !rl.WindowShouldClose() {
		update()
		draw()
		free_all(context.temp_allocator)
	}

	rl.CloseWindow()
}

reset :: proc() {
	hm.clear(&entities)

	player = hm.add(&entities, Entity {
		size = 30,
		color = rl.BLACK,
	})
}

update :: proc() {
	// The pointer `p` is stable, even if you remove from / add to the handle
	// map. This is thanks to the handle map using a fixed array.
	p := hm.get(&entities, player)
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

	if time.duration_seconds(time.since(entity_add_at)) > 0.3 {
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

	if rl.IsKeyPressed(.R) {
		reset()
	}
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLUE)

	ent_iter := hm.make_iter(&entities)
	for e, h in hm.iter(&ent_iter) {
		// e has type ^Entity and h is Entity_Handle. Handle is also accessible
		// using e.handle.

		if h == player {
			continue
		}

		rl.DrawCircleV(e.pos, e.size, e.color)

		// Draw the generation. This says how many times the slot in the handle
		// map has been reused.
		rl.DrawTextEx(rl.GetFontDefault(), fmt.ctprint(h.gen), e.pos - {e.size, e.size}*0.5, e.size, 1, rl.BLACK)
	}

	if p := hm.get(&entities, player); p != nil {
		rl.DrawCircleV(p.pos, p.size, p.color)
	}

	TEXT_SIZE :: 28
	rl.DrawText("entities stats", 5, 5, TEXT_SIZE, rl.BLACK)
	rl.DrawText(fmt.ctprintf("num used: %v", hm.num_used(entities)), 5, 5 + TEXT_SIZE, TEXT_SIZE, rl.BLACK)
	rl.DrawText(fmt.ctprintf("cap: %v", hm.cap(entities)), 5, 5 + TEXT_SIZE*2, TEXT_SIZE, rl.BLACK)
	rl.DrawText(fmt.ctprintf("num unused: %v", entities.num_unused), 5, 5 + TEXT_SIZE*3, TEXT_SIZE, rl.BLACK)

	rl.EndDrawing()
}
