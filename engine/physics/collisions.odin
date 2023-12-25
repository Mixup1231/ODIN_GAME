package physics 
import sp "../spatial"
import mm "../mars_math"

import "core:math"
import "core:fmt"

CollisionLayer :: bit_set[0..<32]

StaticBody :: struct {
    layer: CollisionLayer,
    using aabb: sp.AABB
}

DynamicBody :: struct {
    layer: CollisionLayer,
    using aabb: sp.AABB,
    acceleration: mm.Vec2f,
    velocity: mm.Vec2f,
    boundsCheck: sp.AABB,
    isColliding: bool
}

Ray :: struct {
    origin: mm.Vec2f,
    direction: mm.Vec2f
}

RayIntersect :: struct {
    position: mm.Vec2f,
    normal: mm.Vec2f,
    time: f32
}

rayInAabb :: proc(ray: Ray, aabb: sp.AABB) -> (
    result: bool = false, intersect: RayIntersect
) {
    swap :: proc(x: $T, y: T) -> (T, T) {
        return y, x
    }
    
    invDir: mm.Vec2f = 1 / ray.direction
    near: mm.Vec2f = (aabb.position - ray.origin) * invDir
    far: mm.Vec2f = (aabb.position + aabb.size - ray.origin) * invDir

    if math.is_nan(far[1]) || math.is_nan(far[0]) {
        return
    }
    if math.is_nan(near[1]) || math.is_nan(near[0]) {
        return
    }
    
    //swap near and far components so they are relative to the origin
    if near[0] > far[0] {
        near[0], far[0] = swap(near[0], far[0])
    }
    if near[1] > far[1] {
        near[1], far[1] = swap(near[1], far[1]) 
    }
    
    //ray did not intersect
    if near[0] > far[1] || near[1] > far[0] {
        return
    }

    intersect.time = math.max(near[0], near[1]) //time of near hit
    hitFar: f32 = math.min(far[0], far[1])      //time of far hit

    if hitFar < 0 || intersect.time >= 1 { //if hit is behind or infront
        return
    }
    
    //ray has intersected
    result = true
    intersect.position = ray.origin + intersect.time * ray.direction

    if near[0] > near[1] {        //ray intersected horizontally
        if invDir[0] < 0 {        //ray intersected from the right
            intersect.normal = {1, 0}
        } else {                  //ray intersected from the left
            intersect.normal = {-1, 0}
        }
    } else if near[0] < near[1] { //ray intersected vertically
        if invDir[1] < 0 {        //ray intersected from the top
            intersect.normal = {0, 1}
        } else {                  //ray intersected from the bottom
            intersect.normal = {0, -1}
        }
    }
    
    return
}

bodyInBody :: proc(a: DynamicBody, b: sp.AABB) -> (
    result: bool, intersect: RayIntersect
) {
    if a.velocity == {0, 0} {
        return 
    }

    ray: Ray
    ray.origin = a.position + a.size / 2
    ray.direction = a.velocity

    target: sp.AABB = sp.aabbSum(a, b)
    result, intersect = rayInAabb(ray, target)
    return
}

resolveBodyCollision :: proc(
    using dynamicBody: ^DynamicBody, intersect: RayIntersect 
) {
    assert(dynamicBody != nil)

    absVel: mm.Vec2f = {math.abs(velocity[0]), math.abs(velocity[1])}
    newVel: mm.Vec2f = velocity + intersect.normal * absVel * (1 - intersect.time)
    mag: f32 = mm.vecMag(newVel - velocity)
    if mag > mm.vecMag(velocity) * 2 {
        return
    } else {
        velocity = newVel
    }
}
