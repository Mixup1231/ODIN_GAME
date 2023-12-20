package physics 
import "core:math"
import "core:fmt"

StaticBody :: struct {
    using aabb: AABB
}

DynamicBody :: struct {
    using aabb: AABB,
    acceleration: Vec2f,
    velocity: Vec2f,
    boundsCheck: AABB,
    isColliding: bool
}

Ray :: struct {
    origin: Vec2f,
    direction: Vec2f
}

RayIntersect :: struct {
    position: Vec2f,
    normal: Vec2f,
    time: f32
}

rayInAabb :: proc(ray: Ray, aabb: AABB) -> (
    result: bool = false, intersect: RayIntersect
) {
    swap :: proc(x: $T, y: T) -> (T, T) {
        return y, x
    }
    
    invDir: Vec2f = 1 / ray.direction
    near: Vec2f = (aabb.position - ray.origin) * invDir
    far: Vec2f = (aabb.position + aabb.size - ray.origin) * invDir

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

bodyInBody :: proc(a: DynamicBody, b: AABB) -> (
    result: bool, intersect: RayIntersect
) {
    if a.velocity == {0, 0} {
        return 
    }

    ray: Ray
    ray.origin = a.position + a.size / 2
    ray.direction = a.velocity

    target: AABB = aabbSum(a, b)
    result, intersect = rayInAabb(ray, target)
    return
}

resolveBodyCollision :: proc(
    using dynamicBody: ^DynamicBody, intersect: RayIntersect 
) {
    assert(dynamicBody != nil)

    absVel: Vec2f = {math.abs(velocity[0]), math.abs(velocity[1])}
    newVel: Vec2f = velocity + intersect.normal * absVel * (1 - intersect.time)
    mag: f32 = vecMag(newVel - velocity)
    if mag > vecMag(velocity) * 2 {
        return
    } else {
        velocity = newVel
    }
}
