#+build js
package handle_map

import "core:mem"

Arena :: mem.Dynamic_Arena

arena_init :: proc(arena: ^Arena, block_size: uint) {
	mem.dynamic_arena_init(arena, block_size = int(block_size))
}

arena_destroy :: mem.dynamic_arena_destroy
arena_free_all :: mem.dynamic_arena_free_all
arena_allocator :: mem.dynamic_arena_allocator

arena_initialized :: proc(arena: Arena) -> bool {
	return arena.block_size != 0
}