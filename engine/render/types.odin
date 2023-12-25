package render
import mm "../mars_math"
import sp "../spatial"

import "core:strings"
import "core:fmt"
import rl "vendor:raylib"

MAX_ANIMATION_SHEETS :: 32

Sprite :: struct {
    texture: rl.Texture2D
}

spriteCreate :: proc(fileName: string) -> (result: Sprite) {
    result.texture = rl.LoadTexture(strings.clone_to_cstring(fileName))
    return
}

spriteRender :: proc(sprite: Sprite, source: rl.Rectangle, destination: rl.Rectangle, tint: rl.Color) {
    rl.DrawTexturePro(sprite.texture, source, destination, {0, 0}, 0, tint)
}

AnimatedSprite :: struct {
    spriteSheets: [MAX_ANIMATION_SHEETS]Sprite,
    length: u32,
    currentSheet: u32,
    source: rl.Rectangle,
    frameIndex: u32,
    frameCount: u32,
    cellWidth: i32,
    holdTime: f32,
    time: f32
}

animatedSpriteCreate :: proc(holdTime: f32, fileNames: ..string) -> (result: AnimatedSprite) {
    assert(len(fileNames) < MAX_ANIMATION_SHEETS)
 
    if len(fileNames) > 0 {
        for fileName, i in fileNames {
            result.spriteSheets[i] = spriteCreate(fileName)
        }
        result.length = cast(u32)len(fileNames)
    }

    result.holdTime = holdTime
    
    return
}

animatedSpriteChangeAnimation :: proc(
    using animatedSprite: ^AnimatedSprite, animationIndex: u32, frames: u32
) {
    assert(animatedSprite != nil)
    assert(0 <= animationIndex && animationIndex < length)

    currentSheet = animationIndex
    frameCount = frames
    source.x = 0
    source.y = 0
    cellWidth = spriteSheets[animationIndex].texture.width / cast(i32)frames
    source.width = cast(f32)cellWidth
    source.height = cast(f32)spriteSheets[animationIndex].texture.height
    frameIndex = 0
    time = 0
}

animatedSpriteUpdate :: proc(using animatedSprite: ^AnimatedSprite, dt: f32) {
    assert(animatedSprite != nil)

    time += dt
    if time > holdTime {
        for time > holdTime {
            frameIndex += 1
            frameIndex %= frameCount
            source.x = cast(f32)(frameIndex * cast(u32)cellWidth)
            time -= holdTime
        }
    }
}

animatedSpriteRender :: proc(
    using animatedSprite: ^AnimatedSprite, position: mm.Vec2f, size: mm.Vec2f, color: rl.Color
) {
    assert(animatedSprite != nil)

    rl.DrawTexturePro(
             spriteSheets[currentSheet].texture,
             source,
             {position[0], position[1], size[0], size[1]},
             {0, 0},
             0,
             color)
}

TileMap :: struct($R: f32, $W: f32, $H: f32){
    grid: sp.Grid,
    sprites: [cast(int)(cast(f32)H / cast(f32)R)][cast(int)(cast(f32)W / cast(f32)R)]Sprite
}

tileMapCreate :: proc($R: f32, $W: f32, $H: f32) -> (result: TileMap(R, W, H)) { 
    result.grid = sp.gridCreate({{0, 0}, {W, H}}, R)
    fmt.println(result.grid)
    return
}

tileMapSet :: proc(using tileMap: ^TileMap($R, $W, $H), sprite: Sprite, i: int, j: int) {
    assert(tileMap != nil)
    assert(0 <= i && i < cast(int)(cast(f32)H / cast(f32)R))
    assert(0 <= j && j < cast(int)(cast(f32)W / cast(f32)R))

    sprites[i][j] = sprite
}

tileMapRender :: proc(using tileMap: ^TileMap($R, $W, $H)) {
    assert(tileMap != nil)

    destination: rl.Rectangle
    destination.width = grid.cellWidth
    destination.height = grid.cellHeight
    for row, i in sprites {
        for sprite, j in row {
            destination.x = cast(f32)j * destination.width
            destination.y = cast(f32)i * destination.height
            spriteRender(sprite, {0, 0, cast(f32)sprite.texture.width, cast(f32)sprite.texture.height}, destination, rl.WHITE)
        } 
    }
}

