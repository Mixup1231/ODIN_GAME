package ecs
import "core:fmt"
import "core:mem"
import "core:runtime"
import "core:slice"
 
@private
ECS :: struct {
    initialised: bool,
    entities: EntityArray(MAX_ENTITIES),
    entityCaches: EntityCacheArray(MAX_CACHE, MAX_SYSTEMS),
    signatures: [MAX_ENTITIES]Signature,
    components: [MAX_COMPONENTS]ComponentArray,
    length: KeyType,
    componentToIndex: map[typeid]KeyType,
}

@private
s_ecs: ECS

ecsInit :: proc() {
    assert(!s_ecs.initialised)

    entityArrayInit(&s_ecs.entities)
    entityCacheArrayInit(&s_ecs.entityCaches)
    s_ecs.componentToIndex = make(map[typeid]KeyType)

    s_ecs.initialised = true
    return
}

ecsFree :: proc() {
    using s_ecs
    
    assert(initialised)

    for &component in components {
        if component.components != nil {
            componentArrayDelete(&component)
        }
    }
    entityArrayDelete(&entities)
    entityCacheArrayDelete(&entityCaches)
    delete(componentToIndex)

    initialised = false
}

createEntity :: proc() -> (entity: Entity) {
    using s_ecs

    assert(initialised)

    entity = entityCreate(&entities)
    return
}

deleteEntity :: proc(entity: Entity) {
    using s_ecs

    assert(initialised)
    assert(entityIsValid(&entities, entity))

    for type, index in componentToIndex {
        signature: Signature
        incl(&signature, index)
        if signature <= signatures[entity.key] {
            componentArrayRemove(&components[index], entity.key)
        }
        excl(&signatures[entity.key], index)
    }
    
    updateCaches(entity)
    entityDelete(&s_ecs.entities, entity)
}

registerComponent :: proc($T: typeid) -> bool {
    using s_ecs

    assert(initialised)
    assert(length < MAX_COMPONENTS - 1)

    if T in componentToIndex {
        return false
    }
    
    componentArrayInit(&components[length], T)
    components[length].type = T
    components[length].size = size_of(T)

    componentToIndex[T] = length
    length += 1

    return true
}

insertComponent :: proc($T: typeid, entity: Entity) {
    using s_ecs

    assert(initialised)
    assert(T in componentToIndex)
    assert(entityIsValid(&entities, entity))

    index: KeyType = componentToIndex[T]
    assert(index not_in signatures[entity.key])

    componentArrayInsert(&components[index], entity.key)
    incl(&signatures[entity.key], index)
    
    updateCaches(entity)
}

removeComponent :: proc($T: typeid, entity: Entity) {
    using s_ecs

    assert(initialised)
    assert(T in componentToIndex)
    assert(entityIsValid(&entities, entity))

    index: KeyType = componentToIndex[T]
    assert(index in signatures[entity.key])

    componentArrayRemove(&components[index], entity.key)
    excl(&signatures[entity.key], index)

    updateCaches(entity)
}

getComponent :: proc($T: typeid, entity: Entity) -> ^T {
    using s_ecs

    assert(initialised)
    assert(T in componentToIndex)
    assert(entityIsValid(&entities, entity))

    index: KeyType = componentToIndex[T]
    assert(index in signatures[entity.key])

    return cast(^T)componentArrayGet(&components[index], entity.key)
}

getComponentSignature :: proc(types: ..typeid) -> (result: Signature) {
    using s_ecs

    assert(initialised)
    
    for type in types {
        assert(type in componentToIndex)

        incl(&result, componentToIndex[type])
    }

    return
}

getEntities :: proc(types: ..typeid) -> (result: [dynamic]Entity) {
    using s_ecs

    assert(initialised)

    signature: Signature = getComponentSignature(..types)

    for entity, i in entities.entities {
        if entity.alive && signature <= signatures[i] {
            append_elem(&result, entity)
        }
    }

    return
}

getEntitySignature :: proc(entity: Entity) -> (result: Signature) {
    using s_ecs

    assert(initialised)
    assert(entityIsValid(&entities, entity))

    return signatures[entity.key]
}

@private
updateCaches :: proc(entity: Entity) {
    using s_ecs

    assert(initialised)
    assert(entityIsValid(&entities, entity))

    signature: Signature = signatures[entity.key]

    for &cache, i in entityCaches.caches {
        if cast(KeyType)i == entityCaches.length { // reached end of caches
            break
        }
   
        if signature >= cache.signature && cast(Signature){} != cache.signature {
            entityCacheInsertEntity(&cache, entity)
        } else {
            entityCacheRemoveEntity(&cache, entity)
        } 
    }
}

cacheEntities :: proc(signature: Signature, callback: SystemCallback = nil) {
    using s_ecs

    assert(initialised)
    assert(entityCaches.length < MAX_SYSTEMS - 1)

    for cache, i in entityCaches.caches{
        if cast(KeyType)i == entityCaches.length {
            break
        }

        if (signature == cache.signature) {
            if callback != nil {
                entityCacheInsertSystem(&entityCaches.caches[i], callback)
            }
            return // cache already exists
        }
    }

    cache := entityCacheArrayInsert(&entityCaches)
    entityCacheInsertSystem(cache, callback)
    cache.signature = signature
    for entity, i in entities.entities {
        if entity.alive && signature <= signatures[i] {
            entityCacheInsertEntity(cache, entity)
        }
    }
}

cachedEntitiesGet :: proc(signature: Signature) -> [dynamic]Entity {
    using s_ecs

    for &cache in entityCaches.caches {
        if cache.signature == signature {
            return cache.entities
        }
    }

    assert(false)
    return {}
}   
