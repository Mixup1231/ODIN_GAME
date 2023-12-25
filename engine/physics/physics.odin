package physics
import ecs "../ecs"
import sp "../spatial"
import mm "../mars_math"

import "core:fmt"
import pq "core:container/priority_queue"

staticCallback :: proc(i, j: ecs.Entity, a: ^DynamicBody, b: ^StaticBody, r: RayIntersect)
dynamicCallback :: proc(i, j: ecs.Entity, a: ^DynamicBody, b: ^DynamicBody, r: RayIntersect)

@private
CollisionCallbacks :: struct {
    dynamicBody: dynamicCallback,
    staticBody: staticCallback
}

@private
DynamicPoint :: struct {
    found: bool,
    entity: ecs.Entity,
    body: DynamicBody
}

@private
StaticPoint :: struct {
    found: bool,
    entity: ecs.Entity,
    body: StaticBody
}

@private
Collision :: struct {
    a: ^DynamicPoint,
    collision: union {
        ^StaticPoint,
        ^DynamicPoint,
    },
    intersect: RayIntersect,
}

@private
CollisionTree :: struct($T: typeid) {
    capacity: u32,
    depth: u32,
    bounds: sp.AABB,
    grid: sp.Grid,
    tree: ^sp.QuadTreeNode(T)
}

@private
PhysicsSystem :: struct {
    initialised: bool,
    staticSig: ecs.Signature,
    dynamicSig: ecs.Signature,
    staticTree: CollisionTree(StaticPoint),
    dynamicTree: CollisionTree(DynamicPoint),
    timestep: f32,
    accumulator: f32,
    maxIterations: u32,
    staticOverlap: [dynamic]^StaticPoint,
    dynamicOverlap: [dynamic]^DynamicPoint,
    collisions: pq.Priority_Queue(Collision),
    callbacks: map[ecs.KeyType]CollisionCallbacks,
    gravity: f32
}

@private
s_physicsSystem: PhysicsSystem

physicsInit :: proc(
    bounds: sp.AABB, pointCapacity: u32 = 10, depth: u32 = 5, resolution: f32, iterations: u32 = 8
) {
    ecs.registerComponent(DynamicPoint)
    ecs.registerComponent(StaticPoint)
    
    incl(&s_physicsSystem.staticSig, ecs.getComponentSignature(StaticPoint))
    incl(&s_physicsSystem.dynamicSig, ecs.getComponentSignature(DynamicPoint))

    ecs.cacheEntities(s_physicsSystem.staticSig, updateTreeCallback)
    ecs.cacheEntities(s_physicsSystem.dynamicSig, updateTreeCallback)
    
    s_physicsSystem.timestep = 1.0 / cast(f32)iterations
    s_physicsSystem.maxIterations = iterations

    s_physicsSystem.staticTree.capacity = pointCapacity
    s_physicsSystem.staticTree.depth    = depth
    s_physicsSystem.staticTree.bounds   = bounds
    s_physicsSystem.staticTree.tree     = sp.quadTreeCreate(StaticPoint, pointCapacity, depth, bounds)
    s_physicsSystem.staticTree.grid     = sp.gridCreate(bounds, resolution)

    s_physicsSystem.dynamicTree.capacity = pointCapacity
    s_physicsSystem.dynamicTree.depth    = depth
    s_physicsSystem.dynamicTree.bounds   = bounds
    s_physicsSystem.dynamicTree.tree     = sp.quadTreeCreate(DynamicPoint, pointCapacity, depth, bounds)
    s_physicsSystem.dynamicTree.grid     = sp.gridCreate(bounds, resolution)

    pq.init(&s_physicsSystem.collisions, timeLess, timeSwap)
    s_physicsSystem.callbacks = make(map[ecs.KeyType]CollisionCallbacks)

    s_physicsSystem.gravity = 20000

    s_physicsSystem.initialised = true
}

physicsFree :: proc() {
    using s_physicsSystem
    
    assert(initialised)

    sp.quadTreeFree(staticTree.tree)
    delete(staticOverlap)
    pq.destroy(&collisions)
    delete(callbacks)

    initialised = false
}

setGravity :: proc(newGravity: f32) {
    s_physicsSystem.gravity = newGravity
}

getGravity :: proc(gravity: f32) -> f32{
    return s_physicsSystem.gravity
}

updateTreeCallback :: proc(entity: ecs.Entity, event: ecs.EntityCacheEvent) {
    using s_physicsSystem

    signature: ecs.Signature = ecs.getEntitySignature(entity)
    if signature >= staticSig {
        updateStaticTree()
    } else {
        updateDynamicTree()
    }
}

insertDynamic :: proc(entity: ecs.Entity, a: dynamicCallback = nil, b: staticCallback = nil) {
    using s_physicsSystem

    assert(initialised)

    signature: ecs.Signature = ecs.getEntitySignature(entity)
    assert(!(staticSig <= signature))

    ecs.insertComponent(DynamicPoint, entity)
    callbacks[entity.key] = {a, b}
}

removeDynamic :: proc(entity: ecs.Entity) {
    assert(s_physicsSystem.initialised)

    ecs.removeComponent(DynamicPoint, entity)
    point: ^DynamicPoint = ecs.getComponent(DynamicPoint, entity)
    point.entity = entity
}

getDynamic :: proc(entity: ecs.Entity) -> ^DynamicBody {
    return &ecs.getComponent(DynamicPoint, entity).body
}

getDynamics :: proc() -> [dynamic]ecs.Entity {
    return ecs.cachedEntitiesGet(s_physicsSystem.dynamicSig)
}

@private
physicsAabbInsert :: proc(tree: ^sp.QuadTreeNode($T), grid: sp.Grid, point: ^$Y) {
    aabb := point.body.aabb
    
    widthPoints: u32 = cast(u32)(aabb.size[0] / grid.cellWidth)
    heightPoints: u32 = cast(u32)(aabb.size[1] / grid.cellHeight)
    
    for i in 0..=widthPoints {
        pointOne: mm.Vec2f = {aabb.position[0] + cast(f32)i * grid.cellWidth, aabb.position[1]}
        pointTwo: mm.Vec2f = {aabb.position[0] + cast(f32)i * grid.cellWidth, aabb.position[1] + aabb.size[1]}
        sp.quadTreeInsert(tree, pointOne, point)
        sp.quadTreeInsert(tree, pointTwo, point)
    }

    for i in 1..<heightPoints{
        pointOne: mm.Vec2f = {aabb.position[0], aabb.position[1] + cast(f32)i * grid.cellHeight}
        pointTwo: mm.Vec2f = {aabb.position[0] + aabb.size[0], aabb.position[1] + cast(f32)i * grid.cellHeight}
        sp.quadTreeInsert(tree, pointOne, point)
        sp.quadTreeInsert(tree, pointTwo, point)
    }
}

updateDynamicTree :: proc() {
    using s_physicsSystem
    using dynamicTree

    sp.quadTreeFree(dynamicTree.tree)
    dynamicTree.tree = sp.quadTreeCreate(DynamicPoint, capacity, depth, bounds)

    entities: [dynamic]ecs.Entity = ecs.cachedEntitiesGet(dynamicSig)
    for entity, i in entities {
        point: ^DynamicPoint = ecs.getComponent(DynamicPoint, entity)
        physicsAabbInsert(dynamicTree.tree, dynamicTree.grid, point)
    }
}

insertStatic :: proc(entity: ecs.Entity) {
    using s_physicsSystem

    assert(initialised)
    
    signature: ecs.Signature = ecs.getEntitySignature(entity)
    assert(!(dynamicSig <= signature))

    ecs.insertComponent(StaticPoint, entity)
    point: ^StaticPoint = ecs.getComponent(StaticPoint, entity)
    point.entity = entity
}

removeStatic :: proc(entity: ecs.Entity) {
    assert(s_physicsSystem.initialised)

    ecs.removeComponent(StaticPoint, entity)
}

getStatic :: proc(entity: ecs.Entity) -> ^StaticBody {
    assert(s_physicsSystem.initialised)

    return &ecs.getComponent(StaticPoint, entity).body
}

getStatics :: proc() -> [dynamic]ecs.Entity {
    return ecs.cachedEntitiesGet(s_physicsSystem.staticSig)
}

updateStaticTree :: proc() {
    using s_physicsSystem
    using staticTree

    sp.quadTreeFree(staticTree.tree)
    staticTree.tree = sp.quadTreeCreate(StaticPoint, capacity, depth, bounds)
    
    entities: [dynamic]ecs.Entity = ecs.cachedEntitiesGet(staticSig)
    for entity, i in entities {
        point: ^StaticPoint = ecs.getComponent(StaticPoint, entity)
        physicsAabbInsert(staticTree.tree, staticTree.grid, point)
    }
}

@private
timeLess :: proc(a: Collision, b: Collision) -> bool {
    return a.intersect.time < b.intersect.time
}

@private
timeSwap :: proc(array: []Collision, i, j: int) {
    tmp: Collision = array[i]
    array[i] = array[j]
    array[j] = tmp
}

@private
integrate :: proc() {
    using s_physicsSystem

    entities: [dynamic]ecs.Entity = ecs.cachedEntitiesGet(dynamicSig)
    for entity in entities {
        clear(&staticOverlap)
        clear(&dynamicOverlap)

        point: ^DynamicPoint = ecs.getComponent(DynamicPoint, entity)

        sp.quadTreeGet(staticTree.tree, point.body.boundsCheck, &staticOverlap, true)
        
        // get static collisions
        for staticPoint in staticOverlap {
            intersecting, intersection := bodyInBody(point.body, staticPoint.body)
            if intersecting && point.body.layer - staticPoint.body.layer != point.body.layer {
                collision: Collision
                collision.a = point
                collision.collision = staticPoint
                collision.intersect = intersection
                pq.push(&collisions, collision)
            }
        }
        
        collidedStatic: bool = pq.len(collisions) > 0
        // process static collisions
        for pq.len(collisions) > 0 {
            callback: staticCallback = callbacks[entity.key].staticBody
            collision: Collision = pq.pop(&collisions)

            if callback == nil {
                resolveBodyCollision(&collision.a.body, collision.intersect)
            } else {
                callback(
                    collision.a.entity,
                    collision.collision.(^StaticPoint).entity,
                    &collision.a.body,
                    &collision.collision.(^StaticPoint).body,
                    collision.intersect)
            }
        }

        // get dynamic collisions
        sp.quadTreeGet(dynamicTree.tree, point.body.boundsCheck, &dynamicOverlap, true)

        for dynamicPoint in dynamicOverlap {
            if dynamicPoint == point {
                continue
            }

            intersecting, intersection := bodyInBody(point.body, dynamicPoint.body)
            if intersecting && point.body.layer - dynamicPoint.body.layer != point.body.layer {
                collision: Collision
                collision.a = point
                collision.collision = dynamicPoint
                collision.intersect = intersection
                pq.push(&collisions, collision)
            }
        }
        
        // proccess dynamic collisions
        for pq.len(collisions) > 0 {
            point.body.isColliding = true
            callback: dynamicCallback = callbacks[entity.key].dynamicBody
            collision: Collision = pq.pop(&collisions)

            if callback == nil {
                resolveBodyCollision(&collision.a.body, collision.intersect)
            } else {
                callback(
                    collision.a.entity,
                    collision.collision.(^DynamicPoint).entity,
                    &collision.a.body,
                    &collision.collision.(^DynamicPoint).body,
                    collision.intersect)
            }
        }
    }
    updateDynamicTree()
}

update :: proc(dt: f32) {
    using s_physicsSystem

    assert(initialised)
    
    //scale by timestep
    entities: [dynamic]ecs.Entity = ecs.cachedEntitiesGet(dynamicSig)
    for entity in entities {
        point: ^DynamicPoint = ecs.getComponent(DynamicPoint, entity)
        point.body.acceleration[1] += s_physicsSystem.gravity * dt
        point.body.velocity = point.body.acceleration * (dt * timestep)
    }

    for i in 0..<maxIterations {
        integrate()
    }

    //update positions
    for entity in entities {
        point: ^DynamicPoint = ecs.getComponent(DynamicPoint, entity)
        point.body.position += point.body.velocity
        point.body.boundsCheck.position = sp.aabbGetCentre(point.body) - point.body.boundsCheck.size / 2
    }
}
