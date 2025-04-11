#+build js
package handle_map_growing

import "core:mem"
import "base:runtime"

Arena :: mem.Dynamic_Arena

arena_init :: proc(arena: ^Arena, block_size: int = ARENA_DEFAULT_BLOCK_SIZE, allocator := context.allocator) -> runtime.Allocator_Error {
	mem.dynamic_arena_init(arena, block_allocator = allocator, array_allocator = allocator, block_size = block_size)
	return nil
}

arena_destroy :: mem.dynamic_arena_destroy
arena_free_all :: mem.dynamic_arena_free_all
arena_allocator :: mem.dynamic_arena_allocator
ARENA_DEFAULT_BLOCK_SIZE :: mem.DYNAMIC_ARENA_BLOCK_SIZE_DEFAULT

arena_initialized :: proc(arena: Arena) -> bool {
	return arena.block_size != 0
}