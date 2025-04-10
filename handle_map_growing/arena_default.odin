#+build !js
package handle_map_growing

import vmem "core:mem/virtual"
import "core:fmt"

Arena :: vmem.Arena

arena_init :: proc(arena: ^Arena, block_size: uint) {
	err := vmem.arena_init_growing(arena, block_size)
	fmt.ensuref(err == nil, "Error initializing arena: %v", err)
}

arena_destroy :: vmem.arena_destroy
arena_free_all :: vmem.arena_free_all
arena_allocator :: vmem.arena_allocator

arena_initialized :: proc(arena: Arena) -> bool {
	return arena.curr_block != nil
}