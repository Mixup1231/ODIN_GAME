package debug
import sp "../spatial"
import mm "../mars_math"
import "../physics"

import rl "vendor:raylib"

renderAabb :: proc(using aabb: sp.AABB, color: rl.Color) {
    using sp
    rl.DrawRectangleLines(
        cast(i32)position[0], cast(i32)position[1],
        cast(i32)size[0], cast(i32)size[1],
        color
    )
}

renderRay :: proc(using ray: physics.Ray, color: rl.Color) {
    using sp
    rl.DrawLine(
       cast(i32)origin[0], cast(i32)origin[1],
       cast(i32)(origin[0] + direction[0]), cast(i32)(origin[1] + direction[1]),
       color
    )
}

renderRayIntersect :: proc(
using intersect: physics.RayIntersect, colorA: rl.Color, colorB: rl.Color
) {
    using sp
    rl.DrawCircle(
        cast(i32)position[0], cast(i32)position[1],
        10,
        colorA
    )
    rl.DrawLine(
        cast(i32)position[0], cast(i32)position[1],
        cast(i32)(position[0] + normal[0] * 20), cast(i32)(position[1] + normal[1] * 20),
        colorB
    )
}

renderQuadTree :: proc(using root: ^sp.QuadTreeNode($T)) {
    using sp
    assert(root != nil)
    
    renderAabb(bounds, rl.WHITE)
    for element in data {
        rl.DrawCircle(cast(i32)element.point[0], cast(i32)element.point[1], 5, rl.GREEN)
    }

    for node in nodes {
        if node != nil {
            renderQuadTree(node)
        }
    }
}

renderPoint :: proc(point: mm.Vec2f, color: rl.Color) {
    rl.DrawCircle(cast(i32)point[0], cast(i32)point[1], 10, color)
}
