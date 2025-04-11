# Handle-based map for Odin

This repository contains three variants of a handle-based map.

A handle-based map is a storage container that maps a handle (index + generation) to an item.

The handle can be used as a permanent reference to the items in the map. In other words, the handle can be used where you would normally store a pointer or index.

Handles are good because they store the index ("which item?") and also the generation ("is it actually still the same item?"). Compared to using pointers, using handles also reduces the risk of dangling pointers to items.

Read more about handles:
- [Handles are the better pointers by Andre Weissflog](https://floooh.github.io/2018/06/17/handles-vs-pointers.html)
- [My blog post on Odin implementations](https://zylinski.se/posts/handle-based-arrays/)

Learn more about Odin in my book [Understanding the Odin Programming Language](https://odinbook.com).

## Which variant should I use?

I've written a blog post that gives an overview of this repository: https://zylinski.se/posts/handle-based-maps-three-implementations/

Below I give short summaries of what each variant does.

If you are unsure of which to start with, then I recommend Variant 2, with a big "upper limit".

> [!NOTE]
> The folders are called `handle_map_static` etc, but you can just copy the one you want to your project and rename the folder to `handle_map`.

## Variant 1: `handle_map_static`

This uses a fixed array for storing the items. This means that no dynamic memory allocations are involved. You'll need to supply the maximum size the handle-based map can have. It'll always use that amount of memory.

Example:

```odin
package handle_map_static_example

import hm "handle_map_static"

Entity_Handle :: hm.Handle

Entity :: struct {
	handle: Entity_Handle,
	pos: [2]f32,
}

main :: proc() {
	// Note: We use `1024`, if you use a bigger number within a proc you may
	// blow the stack. In those cases: Store the array inside a global
	// variable or a dynamically allocated struct.
	entities: hm.Handle_Map(Entity, Entity_Handle, 1024)

	h1 := hm.add(&entities, Entity { pos = { 5, 7 } })
	h2 := hm.add(&entities, Entity { pos = { 10, 5 } })

	// Resolve handle -> pointer
	if h2e := hm.get(&entities, h2); h2e != nil {
		h2e.pos.y = 123
	}
	
	// Will remove this entity, leaving an unused slot
	hm.remove(&entities, h1)
	
	// Will reuse the slot h1 used
	h3 := hm.add(&entities, Entity { pos = {1, 2 } })
	
	// Iterate. You can also use `for e in hm.items {}` and
	// skip any item where `e.handle.idx == 0`. The iterator
	// does that automatically.
	ent_iter := hm.make_iter(&entities)
	for e, h in hm.iter(&ent_iter) {
		e.pos += { 5, 1}
	}
}
```

More examples: See `example/static` and `example/static_web`. Web example is live here: https://zylinski.se/odin-handle-map-fixed-example/

## Variant 2: `handle_map_static_virtual`

Uses a static virtual memory arena for the storing the items. You need to choose a maximum theoretical size for the Handle_Map when creating it. Since virtual memory is used, you can choose a very big value. It will just result in a big virtual reservation. The actual memory usage grows as the dynamic array grows into that reserved virtual memory (which will commit it, mapping it to actual physical memory).

Example:

```odin
package handle_map_static_virtual_example

import hm "handle_map_static_virtual"

Entity_Handle :: hm.Handle

Entity :: struct {
	handle: Entity_Handle,
	pos: [2]f32,
}

main :: proc() {
	// You can also use
	// `entities := hm.make(Entity, Entity_Handle, 10000, some_allocator)`
	// to make the `unused_items` array inside the entities map use that
	// allocator.
	//
	// You can use a quite exaggerated number, because this only results
	// in a virtual memory reservation. No physical memory is allocated
	// up-front.
	entities: hm.Handle_Map(Entity, Entity_Handle, 10000)

	h1 := hm.add(&entities, Entity { pos = { 5, 7 } })
	h2 := hm.add(&entities, Entity { pos = { 10, 5 } })

	// Resolve handle -> pointer
	if h2e := hm.get(entities, h2); h2e != nil {
		h2e.pos.y = 123
	}

	// Will remove this entity, leaving an unused slot
	hm.remove(&entities, h1)

	// Will reuse the slot h1 used
	h3 := hm.add(&entities, Entity { pos = {1, 2 } })

	// Iterate. You can also use `for e in hm.items {}` and
	// skip any item where `e.handle.idx == 0`. The iterator
	// does that automatically.
	ent_iter := hm.make_iter(&entities)
	for e, h in hm.iter(&ent_iter) {
		// `h` is equivalent to `e.handle`
		if h == h3 {
			continue
		}

		e.pos += { 5, 1}
	}

	hm.delete(&entities)
}
```

More examples: See `example/static_virtual`

> [!WARNING]
> This implementation does not work on the web, because WASM does not support virtual memory. You could probably use this variant on non-web and then use the Variant 1 on web.

## Variant 3: `handle_map_growing`

This is a generic implementation that does not require you to enter any "maximum number of items". It uses a growing virtual arena when allocating the items of the handle-based map. It also works on web, but then it uses a `Dynamic_Arena`, which is less memory efficient than a virtual arena.

There's one big difference from this variant compared to the two. In this one, the `items` array of `Handle_Map` has elements of type `^T` (pointer to item) instead of just `T`. The items are allocated one-by-one into the growing virtual arena, making them fairly compact in memory. This means you still get quite cache-friendly performance. However, the pointer indirection give a slight penalty in some cases.

Example:

```odin
package handle_map_growing_example

import hm "handle_map_growing"

Entity_Handle :: hm.Handle

Entity :: struct {
	handle: Entity_Handle,
	pos: [2]f32,
}

main :: proc() {
	// You can also use
	// `entities := hm.make(Entity, Entity_Handle, min_items_per_block = 2048)`
	// if you want to tweak the arena block size.
	entities: hm.Handle_Map(Entity, Entity_Handle)

	h1 := hm.add(&entities, Entity { pos = { 5, 7 } })
	h2 := hm.add(&entities, Entity { pos = { 10, 5 } })

	// Resolve handle -> pointer
	if h2e := hm.get(entities, h2); h2e != nil {
		h2e.pos.y = 123
	}

	// Will remove this entity, leaving an unused slot
	hm.remove(&entities, h1)

	// Will reuse the slot h1 used
	h3 := hm.add(&entities, Entity { pos = {1, 2 } })

	// Iterate. You can also use `for e in hm.items {}` and
	// skip any item where `e.handle.idx == 0`. The iterator
	// does that automatically.
	ent_iter := hm.make_iter(&entities)
	for e, h in hm.iter(&ent_iter) {
		// `h` is equivalent to `e.handle`
		if h == h3 {
			continue
		}

		e.pos += { 5, 1}
	}

	hm.delete(&entities)
}
```

More examples: See `example/growing` and `example/growing_web`. Web example is live here: https://zylinski.se/odin-handle-map-example/

## Performance comparison

In the folder `performance_comparison` there's a program that compares the performance when iterating the different variants.

Run the test using:

```
odin run performance_comparison -o:speed
```

They should all have pretty similar performance characteristics.

The `handle_map_static` version is quite easy to convert into an SoA format. There's a comment about that in the `performance_comparsion` code.

You can read more about SoA and how it works in my book [Understanding the Odin Programming Language](https://odinbook.com).
