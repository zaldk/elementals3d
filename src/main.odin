package elementals

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

randf :: rand.float32
Vec3 :: rl.Vector3
Color :: rl.Color

EPSILON :: 0.001

CAMERA : rl.Camera3D
CAM_HEIGHT := 9 * math.sqrt(f32(8) / f32(7))
CAM_SWITCH := false
CAM_TIME : f32 = 0.0
CAM_DELTA : f32 = 1000 // ms
CAM_POS : [2]Vec3

SELECTED_ELEMENTAL : ^Elemental
HOVERED_ELEMENTAL : ^Elemental

CellType :: enum { None, Block, Elemental }
Element :: enum { Fire, Water, Earth, Wind, Energy, Nature }
Elemental :: struct {
    pos: Vec3,
    size: Vec3,
    type: CellType,
    element: Element,

    // level: int,
}
ElementColor := [Element]Color{
    .Fire   = { 204,   0,   0, 255 },
	.Nature = {   0, 204,   0, 255 },
	.Water  = {   0,   0, 204, 255 },
	.Energy = { 204,   0, 204, 255 },
	.Earth  = {  51,  51,  51, 255 },
	.Wind   = { 204, 204, 204, 255 },
}

Board :: struct {
    elementals: [12][12]Elemental,
    turn: int, // even=Blue odd=Green
}

main :: proc() {
    rl.SetConfigFlags({ .WINDOW_ALWAYS_RUN, .WINDOW_RESIZABLE, .MSAA_4X_HINT })
    rl.InitWindow(1600, 1200, "FLOAT")
    defer rl.CloseWindow()
    rl.SetTargetFPS(120)

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
}

new_board :: proc() -> (board: Board) {
    for i in 0..<12 {
        for j in 0..<12 {
            if randf() < 0.33 { continue }
            board.elementals[i][j].type = .Elemental
            board.elementals[i][j].pos = {f32(i-6)+0.5, 0.375, f32(j-6)+0.5}
            board.elementals[i][j].size = {1, 1, 1} * 0.75
            board.elementals[i][j].element = rand.choice_enum(Element)
        }
    }

    return
}

draw_board :: proc(board: Board) {
    draw_board_plane()

    for i in 0..<12 {
        for j in 0..<12 {
            if board.elementals[i][j].type == .None { continue }
            e := board.elementals[i][j]
            collision := raytrace(e.pos - e.size/2, e.pos + e.size/2)
            if collision.hit { draw_wireframe(e.pos, e.size, 0.1, { 127, 127, 127, 255 }) }
            rl.DrawCubeV(e.pos, e.size, ElementColor[e.element])
            rl.DrawCubeWiresV(e.pos, e.size, {0,0,0,255})
        }
    }
}

draw_board_plane :: proc() {
    cell_height :: 0.01
    cell_size := Vec3{1, cell_height, 1}
    for i in -6..<6 {
        for j in -6..<6 {
            col : Color = {0, 0, 0, 255}
            if j < 0 { col.g = 0xC0 } else { col.b = 0xF0 }
            if (i + j) % 2 == 0 { col.rgb = (col.rgb / 10) * 9 }
            cell_pos := Vec3{f32(i), -cell_height/2, f32(j)} + {0.5, 0, 0.5}
            rl.DrawCubeV(cell_pos, cell_size, col)
        }
    }
}

draw_wireframe :: proc(pos, size: Vec3, girth: f32, color: Color) {
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
        rl.DrawCubeWiresV(p, ss[i/4], {0, 0, 0, 255});
    }
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
    c : Vec3 = {math.floor(a.x), math.floor(a.y), math.floor(a.z)} - {math.floor(b.x), math.floor(b.y), math.floor(b.z)}
    c.x = math.abs(c.x)
    c.y = math.abs(c.y)
    c.z = math.abs(c.z)
    return c.x <= EPSILON && c.y <= EPSILON && c.z <= EPSILON
}
equal :: proc(a, b: Vec3) -> bool {
    c := a-b
    c.x = math.abs(c.x)
    c.y = math.abs(c.y)
    c.z = math.abs(c.z)
    return c.x <= EPSILON && c.y <= EPSILON && c.z <= EPSILON
}
