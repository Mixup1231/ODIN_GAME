package mars_math
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
