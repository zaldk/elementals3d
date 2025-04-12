package elementals

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

Vec3 :: rl.Vector3
Color :: rl.Color

TARGET_FPS :: 90
EPSILON :: 0.001
WIRE_GIRTH :: 0.1
CELL_SIZE :: Vec3{ 0.5, 0.5, 0.5 }
CELL_POS :: proc(i,j: int) -> Vec3 { return { f32(i-6)+0.5, (CELL_SIZE.y+WIRE_GIRTH)/2, f32(j-6)+0.5 } }

CAMERA : rl.Camera3D
CAM_HEIGHT := 9 * math.sqrt(f32(8) / f32(7))
CAM_SWITCH := false
CAM_TIME : f32 = 0.0
CAM_DELTA : f32 = 1000 // ms
CAM_POS : [2]Vec3

COLLISION : rl.RayCollision
SELECTED_ELEMENTAL : ^Elemental
HOVERED_ELEMENTAL : ^Elemental

Box :: struct {
    pos: Vec3,
    size: Vec3,
}

ElementColor := [Element][2]Color{
	.Wind   = {{ 0x06, 0xb6, 0xd4, 0xFF }, { 0x7d, 0xd3, 0xfc, 0xFF }},
    .Fire   = {{ 0xfb, 0x92, 0x3c, 0xFF }, { 0xdc, 0x26, 0x26, 0xFF }},
	.Earth  = {{ 0x71, 0x71, 0x7a, 0xFF }, { 0x3f, 0x3f, 0x46, 0xFF }},
	.Water  = {{ 0x0e, 0xa5, 0xe9, 0xFF }, { 0x25, 0x63, 0xeb, 0xFF }},
	.Nature = {{ 0x22, 0xc5, 0x5e, 0xFF }, { 0x0d, 0x94, 0x88, 0xFF }},
	.Energy = {{ 0xd9, 0x46, 0xef, 0xFF }, { 0x6d, 0x28, 0xd9, 0xFF }},
}
Element :: enum { Fire, Water, Earth, Wind, Energy, Nature }
Elemental :: struct {
    type: Element,
    level: int,
}

Block :: struct {}
Empty :: struct {}

CellData :: union {
    Empty,
    Block,
    Elemental,
}

Cell :: struct {
    data: CellData,
    aabb: Box,
}

Tile :: struct {
    aabb: Box,
    color: Color,
}

Board :: struct {
    cells: [12][12]Cell,
    tiles: [12][12]Tile,
    turn: int, // even=Blue odd=Green
}

main :: proc() {
    // {{{
    rl.SetConfigFlags({ .WINDOW_ALWAYS_RUN, .WINDOW_RESIZABLE, .MSAA_4X_HINT })
    rl.InitWindow(1600, 1200, "FLOAT")
    defer rl.CloseWindow()
    rl.SetTargetFPS(TARGET_FPS * 2)

    CAMERA.position = { 6, CAM_HEIGHT, 6 }
    CAMERA.target = { 0, 0, 0 }
    CAMERA.up = { 0, 1, 0 }
    CAMERA.fovy = 15
    CAMERA.projection = .ORTHOGRAPHIC

    board := new_board()

    for !rl.WindowShouldClose() {

        if CAM_SWITCH {
            t := math.unlerp(CAM_TIME, CAM_TIME+CAM_DELTA, f32(rl.GetTime() * 1000))
            if t >= 0 && t <= 1 {
                angle := math.PI/4 + math.PI * smotherstep(t)
                if CAM_POS.x.x < 0 { angle += math.PI }
                CAMERA.position.xz = { f32(math.cos(angle)), f32(math.sin(angle)) } * 6 * math.SQRT_TWO
                CAMERA.position.y = CAM_HEIGHT
            } else {
                CAM_SWITCH = false
            }
        } else if rl.IsMouseButtonPressed(.MIDDLE) {
            CAM_SWITCH = true
            CAM_TIME = f32(rl.GetTime() * 1000)
            CAM_POS.x = CAMERA.position
            CAM_POS.y = CAMERA.position * {-1, 1, -1}
        }

        rl.BeginDrawing()
        {
            rl.ClearBackground({0,0,0,255})
            rl.DrawFPS(0,0)
            rl.BeginMode3D(CAMERA)

            draw_board(board)

            rl.EndMode3D()
        }
        rl.EndDrawing()
    }
    // }}}
}

new_board :: proc() -> (board: Board) {
    // {{{
    tile_height :: 0.01
    for i in 0..<12 {
        for j in 0..<12 {
            tile_color : Color = {0, 0, 0, 255}
            if j < 6 { tile_color.g = 0xC0 } else { tile_color.b = 0xF0 }
            if (i + j) % 2 == 0 { tile_color.rgb = (tile_color.rgb / 10) * 9 }
            board.tiles[i][j].aabb.pos = Vec3{f32(i), -tile_height/2, f32(j)} + {-5.5, 0, -5.5}
            board.tiles[i][j].aabb.size = Vec3{1, tile_height, 1}
            board.tiles[i][j].color = tile_color

            if rand.float32() < 0.25 {
                board.cells[i][j].data = Elemental{ type = rand.choice_enum(Element), level = 1 }
                board.cells[i][j].aabb.pos = CELL_POS(i,j)
                board.cells[i][j].aabb.size = CELL_SIZE
            }
        }
    }

    return
    // }}}
}

draw_board :: proc(board: Board) {
    // {{{
    for i in 0..<12 {
        for j in 0..<12 {
            tile := board.tiles[i][j]
            collision := raytrace(tile.aabb.pos - tile.aabb.size/2, tile.aabb.pos + tile.aabb.size/2)
            if collision.hit { draw_wireframe(tile.aabb.pos, tile.aabb.size, WIRE_GIRTH, { 127, 127, 127, 255 }) }
            rl.DrawCubeV(tile.aabb.pos, tile.aabb.size, tile.color)
        }
    }


    for i in 0..<12 {
        for j in 0..<12 {
            switch data in board.cells[i][j].data {
            case Empty: continue
            case Block: {}
            case Elemental: {
                e := board.cells[i][j].aabb
                // collision := raytrace(e.pos - e.size/2, e.pos + e.size/2)
                // if collision.hit { draw_wireframe(e.pos, e.size, 0.1, { 127, 127, 127, 255 }) }
                rl.DrawCubeV(e.pos, e.size, ElementColor[data.type][0])
                draw_wireframe(e.pos, e.size, WIRE_GIRTH, ElementColor[data.type][1])
                // rl.DrawCubeWiresV(e.pos, e.size, {0,0,0,255})
            }
            }
        }
    }
    // }}}
}

draw_wireframe :: proc(pos, size: Vec3, girth: f32, color: Color, recurse := true) {
    // {{{
    vs := [8]Vec3{ // vertices
        pos + size / 2 * { -1, -1, -1 },
        pos + size / 2 * { +1, -1, -1 },
        pos + size / 2 * { -1, +1, -1 },
        pos + size / 2 * { +1, +1, -1 },
        pos + size / 2 * { -1, -1, +1 },
        pos + size / 2 * { +1, -1, +1 },
        pos + size / 2 * { -1, +1, +1 },
        pos + size / 2 * { +1, +1, +1 },
    }

    es := [12][2]Vec3{ // edges
        { vs[0], vs[1] },
        { vs[2], vs[3] },
        { vs[4], vs[5] },
        { vs[6], vs[7] },

        { vs[0], vs[2] },
        { vs[1], vs[3] },
        { vs[4], vs[6] },
        { vs[5], vs[7] },

        { vs[0], vs[4] },
        { vs[1], vs[5] },
        { vs[2], vs[6] },
        { vs[3], vs[7] },
    }

    ps : [12]Vec3 // points
    for e, i in es { ps[i] = (e.x + e.y) / 2 }

    ss : [3]Vec3 // sizes
    ss[0] = { size.x, 0, 0 } + girth // * { -1, 1, 1 }
    ss[1] = { 0, size.y, 0 } + girth // * { 1, -1, 1 }
    ss[2] = { 0, 0, size.z } + girth // * { 1, 1, -1 }

    for p, i in ps {
        rl.DrawCubeV(p, ss[i/4], color)
        // rl.DrawCubeWiresV(p, ss[i/4], {0, 0, 0, 255});
    }
    // rl.DrawCubeWiresV(pos, size+0.1, {0, 0, 0, 255}, false);
    if recurse { draw_wireframe(pos, size+0.1, WIRE_GIRTH/5, {0,0,0,255}, false) }
    // }}}
}

raytrace :: proc(min_bound, max_bound: Vec3) -> rl.RayCollision {
    return rl.GetRayCollisionBox(rl.GetScreenToWorldRay(rl.GetMousePosition(), CAMERA), {min_bound, max_bound})
}

lerp :: proc{ math.lerp, lerp_Vec3 }
lerp_Vec3 :: proc(a, b: Vec3, t: f32) -> Vec3 { return a * (1 - t) + b * t }

smotherstep :: proc(x: f32) -> f32 {
    return x * x * x * (x * (6 * x - 15) + 10)
}

equal_floor :: proc(a, b: Vec3) -> bool {
    for i in 0..<3 {
        if math.abs(math.floor(a[i]) - math.floor(b[i])) >= EPSILON {
            return false
        }
    }
    return true
}
equal :: proc(a, b: Vec3) -> bool {
    c := a-b
    c.x = math.abs(c.x)
    c.y = math.abs(c.y)
    c.z = math.abs(c.z)
    return c.x <= EPSILON && c.y <= EPSILON && c.z <= EPSILON
}
