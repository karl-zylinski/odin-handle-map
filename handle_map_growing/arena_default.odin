#+build !js
package handle_map_growing

import vmem "core:mem/virtual"
import "base:runtime"

Arena :: vmem.Arena

@require_results
arena_init :: proc(arena: ^Arena, block_size: int = ARENA_DEFAULT_BLOCK_SIZE, allocator := context.allocator) -> runtime.Allocator_Error {
	return vmem.arena_init_growing(arena, uint(block_size))

	// NOTE: allocator not used, it's just for the JS version.
}

arena_destroy :: vmem.arena_destroy
arena_free_all :: vmem.arena_free_all
arena_allocator :: vmem.arena_allocator
ARENA_DEFAULT_BLOCK_SIZE :: vmem.DEFAULT_ARENA_GROWING_MINIMUM_BLOCK_SIZE

arena_initialized :: proc(arena: Arena) -> bool {
	return arena.curr_block != nil
}