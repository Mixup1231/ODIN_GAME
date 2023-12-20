package physics 
import "core:math"

Vec2f :: [2]f32
Vec2i :: [2]i32

vecMag :: proc (v: [$N]$T) -> T {
    total: T
    for component in v {
        total += component * component
    }
    return math.sqrt(total)
}

vecNorm :: proc(v: [$N]$T) -> (norm: [N]T) {
    mag: T = vecMag(v)
    norm = v / mag
    return
}

AABB :: struct {
    position: Vec2f,
    size: Vec2f
}

AabbDivisions :: enum {
    BOTTOM_LEFT,
    BOTTOM_RIGHT,
    TOP_LEFT,
    TOP_RIGHT
}

aabbGetCorners :: proc(using aabb: AABB) -> (result: [4]Vec2f) {
    using AabbDivisions

    result[BOTTOM_LEFT]  = {position[0], position[1]}
    result[BOTTOM_RIGHT] = {position[0] + size[0], position[1]}
    result[TOP_LEFT]     = {position[0], position[1] + size[1]}
    result[TOP_RIGHT]    = {position[0] + size[0], position[1] + size[1]}
    return
}

aabbGetCentre :: proc(using aabb: AABB) -> (result: Vec2f) {
    result = position + size / 2
    return
}

aabbSubdivide :: proc(using aabb: AABB) -> (result: [4]AABB) {
    using AabbDivisions

    newSize: Vec2f = size / 2
    result[BOTTOM_LEFT]  = {position, newSize}
    result[BOTTOM_RIGHT] = {{position[0] + newSize[0], position[1]}, newSize}
    result[TOP_LEFT]     = {{position[0],position[1] + newSize[1]}, newSize}
    result[TOP_RIGHT]    = {position + newSize, newSize}
    return
}

pointInAabb :: proc(point: Vec2f, aabb: AABB) -> bool {
    return (point[0] >= aabb.position[0] &&
            point[0] < aabb.position[0] + aabb.size[0] &&
            point[1] >= aabb.position[1] &&
            point[1] < aabb.position[1] + aabb.size[1])
}

aabbSum :: proc(a: AABB, b: AABB) -> (result: AABB) {
    result.position = b.position - a.size / 2
    result.size = a.size + b.size
    return
}

aabbInAabb :: proc(a: AABB, b: AABB) -> bool {
    sum: AABB = aabbSum(a, b)
    centre: Vec2f = a.position + a.size / 2
    return pointInAabb(centre, sum)
}
