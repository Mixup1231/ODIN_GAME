package spatial
import mm "../mars_math"

Grid :: struct {
    bounds: AABB,
    resolution: f32,
    cellWidth: f32,
    cellHeight: f32
}

gridCreate :: proc(bounds: AABB, resolution: f32) -> (result: Grid) {
    result.bounds = bounds
    result.resolution = resolution
    result.cellWidth = bounds.size[0] / resolution
    result.cellHeight = bounds.size[1] / resolution

    return
}

gridSegmentAabb :: proc(grid: Grid, aabb: AABB) -> (result: [dynamic]mm.Vec2f) {
    if !aabbInAabb(aabb, grid.bounds) {
        return //not inside grid
    }    

    widthPoints: u32 = cast(u32)(aabb.size[0] / grid.cellWidth)
    heightPoints: u32 = cast(u32)(aabb.size[1] / grid.cellHeight)
    
    for i in 0..=widthPoints {
        pointOne: mm.Vec2f = {aabb.position[0] + cast(f32)i * grid.cellWidth, aabb.position[1]}
        pointTwo: mm.Vec2f = {aabb.position[0] + cast(f32)i * grid.cellWidth, aabb.position[1] + aabb.size[1]}
        append_elem(&result, pointOne)
        append_elem(&result, pointTwo)
    }

    for i in 1..<heightPoints{
        pointOne: mm.Vec2f = {aabb.position[0], aabb.position[1] + cast(f32)i * grid.cellHeight}
        pointTwo: mm.Vec2f = {aabb.position[0] + aabb.size[0], aabb.position[1] + cast(f32)i * grid.cellHeight}
        append_elem(&result, pointOne)
        append_elem(&result, pointTwo)
    }
    
    return

}
