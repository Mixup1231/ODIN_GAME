package ecs

Entity :: struct {
    alive: bool,
    key: KeyType,
    generation: u64
}

entityEquality :: proc(a: Entity, b: Entity) -> bool {
    return (
        a.alive      == b.alive &&
        a.key        == b.key &&
        a.generation == b.generation
    )
}

@private
EntityArray :: struct($N: KeyType) {
    entities: [N]Entity,
    slots: [dynamic]KeyType
}

@private
entityArrayInit :: proc(using entityArray: ^EntityArray($N)) {
    assert(entityArray != nil)
    
    slots = make([dynamic]KeyType)
    key: u32
    for i in 0..<N {
        key = N - 1 - cast(KeyType)i
        append_elem(&slots, key)
        entities[key].key = key
        entities[key].generation = 0
    }
}

@private
entityArrayDelete :: proc(using entityArray: ^EntityArray($N)) {
    assert(entityArray != nil && len(slots) > 0)

    delete(slots)
}

@private
entityCreate :: proc(using entityArray: ^EntityArray($N)) -> (result: Entity) {
    assert(entityArray != nil && len(slots) > 0)

    key: KeyType = pop(&slots)
    entities[key].alive = true
    result = entities[key]
    return
}

@private
entityDelete :: proc(using entityArray: ^EntityArray($N), entity: Entity) {
    assert(entityArray != nil)
    assert(entityIsValid(entityArray, entity))

    append_elem(&slots, entity.key)
    entities[entity.key].generation += 1
    entities[entity.key].alive = false
}

@private
entityIsValid :: proc(using entityArray: ^EntityArray($N), entity: Entity) -> bool {
    assert(entityArray != nil)
    return (
        (0 <= entity.key && entity.key < N) &&
        entities[entity.key].generation == entity.generation
    )
}
