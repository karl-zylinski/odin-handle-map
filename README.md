# Handle-based map for Odin

Map a handle (index + generation) to an item.

Uses a growing virtual memory arena for the storing the items. This makes pointers stable but the memory is still compact, which makes the performance good when iterating (cache friendly).

Read more about handles:
- [Handles are the better pointers by Andre Weissflog](https://floooh.github.io/2018/06/17/handles-vs-pointers.html)
- [My blog post on Odin implementations](https://zylinski.se/posts/handle-based-arrays/)

## Quick start

```odin
import hm "handle_map"

Entity_Handle :: hm.Handle

Entity :: struct {
	handle: Entity_Handle,
	pos: [2]f32,
}

main :: proc() {
	entities: hm.Handle_Map(Entity, Entity_Handle)

	h1 := hm.add(&entities, Entity { pos = { 5, 7 } })
	hm.add(&entities, Entity { pos = { 10, 5 } })

	if h2e := hm.get(entities, h1); h2e != nil {
		h2e.pos.y = 123
	}

	hm.remove(&entities, h1)

	h3 := hm.add(&entities, Entity { pos = {1, 2 } })

	ent_iter := hm.make_iter(&entities)
	for e, h in hm.iter(&ent_iter) {
		if h == h3 {
			continue
		}

		e.pos += { 5, 1}
	}
}
```

## Example (little video game)

![image](https://github.com/user-attachments/assets/013b0c41-3f28-4592-9854-198bc1427b47)

See `example` folder. It's a game where the player is a circle and you move the mouse to consume other circles. It adds, removes and iterates the handle map. The numbers inside each circle is that entity's generation.

## Web support

Live demo build from `example_web` folder: https://zylinski.se/odin-handle-map-example/

> [!NOTE]
> WASM does not support virtual memory. So on web I use a Dynamic Arena instead of a Growing Virtual Arena. Not using a virtual arena is slightly less efficient with regards to memory use, so you may want to tweak the block size. This is done like this in the `example_web` demo:

```odin
entities = hm.make(Entity, Entity_Handle, min_items_per_block = 128) // default is 1024
```
