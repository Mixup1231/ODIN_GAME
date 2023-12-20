package ecs
import "core:slice"
import "core:fmt"

SystemCallback :: proc(entity: Entity, event: EntityCacheEvent)

EntityCacheEvent :: enum {
    ENTITY_INSERTED,
    ENTITY_REMOVED
}

@private
EntityCache :: struct($N: KeyType) {
    entities: [dynamic]Entity,
    signature: Signature,
    callbacks: [N]SystemCallback,
    length: KeyType
}

@private
entityCacheInsertSystem :: proc(using cache: ^EntityCache($N), callback: SystemCallback) {
    assert(cache != nil)
    assert(0 <= length && length < N)

    found: bool
    for storedCallback in callbacks {
        if storedCallback == nil {
            break
        } else if storedCallback == callback {
            found = true
            break
        }
    }

    assert(!found)

    callbacks[length] = callback
    length += 1
}

@private
entityCacheInsertEntity :: proc(using cache: ^EntityCache($N), entity: Entity) {
    assert(cache != nil)
    
    found: bool
    for storedEntity, i in entities {
        if entityEquality(storedEntity, entity) {
            found = true
        }
    }

    if found {
        return
    }

    append_elem(&entities, entity)
    
    for callback in callbacks {
        if callback != nil {
            callback(entity, EntityCacheEvent.ENTITY_INSERTED)
        } else {
            break
        }
    }
}

@private
entityCacheRemoveEntity :: proc(using cache: ^EntityCache($N), entity: Entity) {
    assert(cache != nil)
    
    index: KeyType
    found: bool
    for storedEntity, i in entities {
        if entityEquality(storedEntity, entity) {
            index = cast(KeyType)i
            found = true
            break
        }
    }
    
    if !found {
        return
    }
    
    unordered_remove(&entities, cast(int)index)

    for callback in callbacks {
        if callback != nil {
            callback(entity, EntityCacheEvent.ENTITY_REMOVED)
        } else {
            break
        }
    }
}

@private
EntityCacheArray :: struct($N: KeyType, $M: KeyType) {
    caches: [N]EntityCache(M),
    length: KeyType
}

entityCacheArrayInit :: proc(using array: ^EntityCacheArray($N, $M)) {
    assert(array != nil)

    for &cache in caches {
        cache.entities = make([dynamic]Entity)
    }
}

entityCacheArrayDelete :: proc(using array: ^EntityCacheArray($N, $M)) {
    assert(array != nil)

    for &cache in caches {
        delete(cache.entities)
    }
}

entityCacheArrayInsert :: proc(using array: ^EntityCacheArray($N, $M)) -> ^EntityCache(M) {
    assert(array != nil)
    assert(length <= N - 1)

    defer length += 1
    return &caches[length]
}
