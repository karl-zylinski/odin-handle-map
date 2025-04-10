/*
Same as ../example but works on web.
*/

package handle_map_example_web

import hm "../../handle_map_growing"
import rl "vendor:raylib"
import "core:time"
import "core:math/rand"
import "core:fmt"
import "base:runtime"
import "core:mem"
import "core:c"

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
web_context: runtime.Context

@export
main_start :: proc "c" () {
	context = runtime.default_context()
	context.allocator = emscripten_allocator()
	runtime.init_global_temporary_allocator(1*mem.Megabyte)

	web_context = context

	// The default for min_items_per_block is 1024. On web we don't have virtual
	// memory, so we set it to 128. That will lower the memory usage, since
	// all the whole block will be allocated (committed) at once when using
	// non-virtual memory.
	entities = hm.make(Entity, Entity_Handle, min_items_per_block = 128)

	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "Odin Handle_Map demo (handle_map_growing)")

	player = hm.add(&entities, Entity {
		size = 30,
		color = rl.BLACK,
	})

	assert(hm.valid(entities, player), "The player entity is invalid.")
}

@export
main_update :: proc "c" () -> bool {
	context = web_context
	update()
	draw()
	free_all(context.temp_allocator)
	return true
}

@export
main_end :: proc "c" () {
	context = web_context
	hm.delete(&entities)
	rl.CloseWindow()
}

@export
web_window_size_changed :: proc "c" (w: c.int, h: c.int) {
	context = web_context
	rl.SetWindowSize(w, h)
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
		rl.DrawTextEx(rl.GetFontDefault(), fmt.ctprint(h.gen), e.pos - {e.size, e.size}*0.5, e.size, 1, rl.BLACK)
	}

	if p := hm.get(entities, player); p != nil {
		rl.DrawCircleV(p.pos, p.size, p.color)
	}

	TEXT_SIZE :: 28
	rl.DrawText("entities stats", 5, 5, TEXT_SIZE, rl.BLACK)
	rl.DrawText(fmt.ctprintf("len: %v", hm.len(entities)), 5, 5 + TEXT_SIZE, TEXT_SIZE, rl.BLACK)
	rl.DrawText(fmt.ctprintf("unused slots: %v", len(entities.unused_items)), 5, 5 + TEXT_SIZE*2, TEXT_SIZE, rl.BLACK)
	rl.DrawText(fmt.ctprintf("arena num full blocks: %v", len(entities.items_arena.used_blocks)), 5, 5 + TEXT_SIZE*3, TEXT_SIZE, rl.BLACK)
	rl.DrawText(fmt.ctprintf("arena bytes left: %v b", entities.items_arena.bytes_left), 5, 5 + TEXT_SIZE*4, TEXT_SIZE, rl.BLACK)

	rl.EndDrawing()
}
