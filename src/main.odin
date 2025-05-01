package elementals

import "core:fmt"
import "core:strings"
import "core:math"
import "core:math/ease"
import "core:math/rand"
import "core:mem"
import "base:intrinsics"
import rl "vendor:raylib"
import tw "tailwind"

Vec3 :: rl.Vector3
Color :: rl.Color
TW :: tw.TW

BLACK :: Color{0,0,0,255}
WHITE :: Color{255,255,255,255}

ENABLED_SHADERS :: #config(SHADERS, false)
TARGET_FPS :: 120
EPSILON :: 0.001
HEALTH_LEVEL := [?]int{ -1, 1, 2, 6 }
DAMAGE_LEVEL := [?]int{ -1, 1, 2, 4 }
REACH_LEVEL  := [?]int{ -1, 3, 5, 7 }
SPELL_DAMAGE := [Spell]int{ .FS = 2, .HV = -1, .AF = 1, .DT = -1, .MS = 4 }
SPELL_CHARGE := [Spell]int{ .FS = 4, .HV = 5, .AF = 7, .DT = 9, .MS = 10 }

CAMERA : rl.Camera3D
CAM_HEIGHT := 9 * math.sqrt(f32(8) / f32(7))

COLLISION := rl.RayCollision{ distance = math.F32_MAX }
SELECTED_CELL := [2]int{-1, -1}
HOVERING_CELL := [2]int{-1, -1}

MAX_BOXES :: 1024
ALL_BOXES_INDEX := 0
ALL_BOXES : [MAX_BOXES]Box

DRAW_BOARD := true

VERTEX_SHADER :: #load("resources/vertex.glsl", cstring)
FRAGMENT_SHADER :: #load("resources/fragment.glsl", cstring)

Spell :: enum { FS, HV, AF, DT, MS }

Box :: struct {
    pos: Vec3,
    size: Vec3,
}

ElementColor := [Element][2]Color{
    .Error  = { {0,0,0,255}, {255,0,255,255} },
    .Air    = { TW(.CYAN5   ), TW(.SKY3    ) }, // {{ 0x06, 0xB6, 0xD4, 0xFF }, { 0x7D, 0xD3, 0xFC, 0xFF }},
    .Fire   = { TW(.ORANGE4 ), TW(.RED6    ) }, // {{ 0xFB, 0x92, 0x3C, 0xFF }, { 0xDC, 0x26, 0x26, 0xFF }},
    .Rock   = { TW(.ZINC5   ), TW(.ZINC7   ) }, // {{ 0x71, 0x71, 0x7A, 0xFF }, { 0x3F, 0x3F, 0x46, 0xFF }},
    .Water  = { TW(.SKY5    ), TW(.BLUE6   ) }, // {{ 0x0E, 0xA5, 0xE9, 0xFF }, { 0x25, 0x63, 0xEB, 0xFF }},
    .Nature = { TW(.GREEN5  ), TW(.TEAL6   ) }, // {{ 0x22, 0xC5, 0x5E, 0xFF }, { 0x0D, 0x94, 0x88, 0xFF }},
    .Energy = { TW(.FUCHSIA5), TW(.VIOLET7 ) }, // {{ 0xD9, 0x46, 0xEF, 0xFF }, { 0x6D, 0x28, 0xD9, 0xFF }},
}
Element :: enum { Error, Air, Fire, Rock, Water, Nature, Energy }
Elemental :: struct {
    type: Element,
    level: int,
    health: int,
}
Block :: struct {}
Empty :: struct {}

CellType :: enum { Empty, Block, Elemental, }

Cell :: struct {
    aabb: Box,
    type: CellType,
    data: Elemental,
}

PlayerType :: enum { Blue, Green }
Tile :: struct {
    color: Color,
    player: PlayerType,
}

Board :: struct {
    cells: [12][12]Cell,
    tiles: [12][12]Tile,
    turn: int, // even=Blue odd=Green
}

// ActionType :: enum { Move, Attack, Spell, Skip }
// Action :: struct {
//     type: ActionType,
// }

AnimationType :: enum { Move, Attack, Spell }
ANIMATION := struct {
    active: bool,
    type: AnimationType,
    duration: f32, // ms
    start:    f32, // ms
    from: [2]int, // grid positions
    to:   [2]int, // grid positions
}{
    active = false,
    from = {-1,-1},
    to   = {-1,-1},
    duration = 1000,
}

main :: proc() {
    // {{{
    // {{{ Tracking + Temp. Allocator
    // track my faulty programming
    // taken from youtube.com/watch?v=dg6qogN8kIE
    default_allocator := context.allocator
    tracking_allocator : mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracking_allocator, default_allocator)
    context.allocator = mem.tracking_allocator(&tracking_allocator)
    defer {
        for key, value in tracking_allocator.allocation_map {
            fmt.printfln("[%v] %v leaked %v bytes", key, value.location, value.size)
        }
        for value in tracking_allocator.bad_free_array {
            fmt.printfln("[%v] %v double free detected", value.memory, value.location)
        }
        mem.tracking_allocator_clear(&tracking_allocator)
    }
    defer free_all(context.temp_allocator)
    // }}}

    // {{{ Initial Variables
    rl.SetConfigFlags({ .WINDOW_ALWAYS_RUN, .WINDOW_RESIZABLE, .MSAA_4X_HINT })
    rl.InitWindow(1600, 1200, "FLOAT")
    defer rl.CloseWindow()
    rl.SetTargetFPS(TARGET_FPS)

    CAMERA.position = { 6, CAM_HEIGHT, 6 }
    CAMERA.target = { 0, 0, 0 }
    CAMERA.up = { 0, 1, 0 }
    CAMERA.fovy = 15
    CAMERA.projection = .ORTHOGRAPHIC

    when ENABLED_SHADERS {
        shader := rl.LoadShaderFromMemory(VERTEX_SHADER, FRAGMENT_SHADER)
        defer rl.UnloadShader(shader)
        shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW] = rl.GetShaderLocation(shader, "viewPos");

        t1 := tw.TW_RANDOM()
        c1 := [3]f32{ f32(t1.r) / 255.0, f32(t1.g) / 255.0, f32(t1.b) / 255.0 }
        rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "bg_color_1"), raw_data(c1[:]), .VEC3)

        t2 := tw.TW_RANDOM()
        c2 := [3]f32{ f32(t2.r) / 255.0, f32(t2.g) / 255.0, f32(t2.b) / 255.0 }
        rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "bg_color_2"), raw_data(c2[:]), .VEC3)

        display_resolution := [2]f32{ f32(rl.GetMonitorWidth(rl.GetCurrentMonitor())), f32(rl.GetMonitorHeight(rl.GetCurrentMonitor())) }
        rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "display_resolution"), raw_data(display_resolution[:]), .VEC2)
    }

    BOARD := new_board()
    // }}}

    // {{{ The Game Loop
    for !rl.WindowShouldClose() {
        // {{{ Collision Calculation
        COLLISION = rl.RayCollision{ distance = math.F32_MAX }
        for i in 0..<12 {
            for j in 0..<12 {
                tile := get_tile_aabb(i,j)
                tile_collision := raytrace(tile.pos - tile.size/2, tile.pos + tile.size/2)

                cell_collision := tile_collision
                if BOARD.cells[i][j].type == .Elemental {
                    cell := get_cell_aabb(i, j, BOARD.cells[i][j].data.level)
                    cell_collision = raytrace(cell.pos - cell.size/2, cell.pos + cell.size/2)
                }

                switch {
                case !tile_collision.hit && !cell_collision.hit: continue

                case !tile_collision.hit && cell_collision.hit:
                    if COLLISION.distance > cell_collision.distance { COLLISION = cell_collision }

                case tile_collision.hit && !cell_collision.hit:
                    if COLLISION.distance > tile_collision.distance { COLLISION = tile_collision }

                case tile_collision.hit && cell_collision.hit: {
                    min_collision := tile_collision
                    if min_collision.distance > cell_collision.distance { min_collision = cell_collision }
                    if COLLISION.distance > min_collision.distance { COLLISION = min_collision }
                }
                }
            }
        }
        // }}}

        // {{{ Animations + Logic
        if ANIMATION.active {
            switch ANIMATION.type {
            case .Move: {
                assert(valid(ANIMATION.from))
                cell_from := BOARD.cells[ANIMATION.from.x][ANIMATION.from.y]
                assert(cell_from.type == .Elemental)
                data_from := cell_from.data
                aabb_from := get_cell_aabb(ANIMATION.from, data_from.level)

                assert(valid(ANIMATION.to))
                cell_to := BOARD.cells[ANIMATION.to.x][ANIMATION.to.y]
                assert(cell_to.type == .Empty)
                data_to := cell_to.data
                aabb_to := get_cell_aabb(ANIMATION.to, data_from.level)

                t := math.unlerp(ANIMATION.start, ANIMATION.start+ANIMATION.duration, get_time())
                t = ease.cubic_in_out(t)
                if t >= 0 && t <= 1 {
                    BOARD.cells[ANIMATION.from.x][ANIMATION.from.y].aabb.pos = math.lerp(aabb_from.pos, aabb_to.pos, t)
                } else {
                    BOARD.cells[ANIMATION.to.x][ANIMATION.to.y] = BOARD.cells[ANIMATION.from.x][ANIMATION.from.y]
                    BOARD.cells[ANIMATION.to.x][ANIMATION.to.y].aabb = get_cell_aabb(ANIMATION.to, data_from.level)
                    BOARD.cells[ANIMATION.from.x][ANIMATION.from.y] = Cell{ type = .Empty }
                    ANIMATION.active = false
                    ANIMATION.start = 0
                    ANIMATION.from = -1
                    ANIMATION.to = -1
                }
            }
            case .Attack: {
                assert(valid(ANIMATION.from))
                cell_from := &BOARD.cells[ANIMATION.from.x][ANIMATION.from.y]
                assert(cell_from.type == .Elemental)
                data_from := cell_from.data
                aabb_from := get_cell_aabb(ANIMATION.from, data_from.level)

                assert(valid(ANIMATION.to))
                cell_to := &BOARD.cells[ANIMATION.to.x][ANIMATION.to.y]
                assert(cell_from.type == .Elemental)
                data_to := cell_to.data
                aabb_to := get_cell_aabb(ANIMATION.to, data_from.level)

                t := math.unlerp(ANIMATION.start, ANIMATION.start+ANIMATION.duration, get_time())
                if t >= 0 && t < 0.5 {
                    BOARD.cells[ANIMATION.from.x][ANIMATION.from.y].aabb.pos = math.lerp(aabb_from.pos, aabb_to.pos, ease.cubic_in_out(t*2))
                } else if t >= 0.5 && t < 1 {
                    BOARD.cells[ANIMATION.from.x][ANIMATION.from.y].aabb.pos = math.lerp(aabb_to.pos, aabb_from.pos, ease.cubic_in_out((t-0.5)*2))
                } else {
                    cell_to.data.health = math.clamp(data_to.health - DAMAGE_LEVEL[data_from.level], 0, HEALTH_LEVEL[data_to.level])
                    if cell_to.data.health == 0 {
                        cell_to.data.level -= 1
                        if cell_to.data.level == 0 {
                            BOARD.cells[ANIMATION.to.x][ANIMATION.to.y] = Cell{}
                        } else {
                            cell_to.data.health = HEALTH_LEVEL[cell_to.data.level]
                            cell_to.aabb.size = get_cell_size(cell_to.data.level)
                        }
                    }
                    SELECTED_CELL = {-1,-1}
                    ANIMATION.active = false
                    ANIMATION.start = 0
                    ANIMATION.from = -1
                    ANIMATION.to = -1
                }
            }
            case .Spell: {}
            }
        }
        // }}}

        // {{{ Input
        if !rl.IsKeyDown(.LEFT_SHIFT) && rl.GetMouseWheelMoveV().y < 0 { CAMERA.fovy *= 1.1 }
        if !rl.IsKeyDown(.LEFT_SHIFT) && rl.GetMouseWheelMoveV().y > 0 { CAMERA.fovy *= 0.9 }
        if  rl.IsKeyDown(.LEFT_SHIFT) && rl.GetMouseWheelMoveV().y < 0 { rotate_camera(-1) }
        if  rl.IsKeyDown(.LEFT_SHIFT) && rl.GetMouseWheelMoveV().y > 0 { rotate_camera(+1) }
        if rl.GetMouseWheelMoveV().x < 0 { rotate_camera(-1) }
        if rl.GetMouseWheelMoveV().x > 0 { rotate_camera(+1) }

        if COLLISION.hit {
            i, j := point2grid(COLLISION.point)
            HOVERING_CELL = {i,j}
            if BOARD.cells[i][j].type == .Elemental {
                rl.SetMouseCursor(.POINTING_HAND)
            } else {
                rl.SetMouseCursor(.DEFAULT)
            }
        }

        key := rl.GetKeyPressed()
        if !ANIMATION.active && key == .Q { BOARD = new_board() }
        if !ANIMATION.active && key == .W { DRAW_BOARD = !DRAW_BOARD }
        when ENABLED_SHADERS {
            if !ANIMATION.active && key == .E {
                t1 := tw.TW_RANDOM()
                c1 := [3]f32{ f32(t1.r) / 255.0, f32(t1.g) / 255.0, f32(t1.b) / 255.0 }
                rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "bg_color_1"), raw_data(c1[:]), .VEC3)

                t2 := tw.TW_RANDOM()
                c2 := [3]f32{ f32(t2.r) / 255.0, f32(t2.g) / 255.0, f32(t2.b) / 255.0 }
                rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "bg_color_2"), raw_data(c2[:]), .VEC3)
            }
        }

        if !ANIMATION.active && rl.IsMouseButtonPressed(.LEFT) && COLLISION.hit {
            if valid(SELECTED_CELL) && valid(HOVERING_CELL) && !equal(SELECTED_CELL[:], HOVERING_CELL[:]) {
                if BOARD.cells[HOVERING_CELL.x][HOVERING_CELL.y].type == .Empty &&
                   BOARD.cells[SELECTED_CELL.x][SELECTED_CELL.y].type == .Elemental {
                    ANIMATION.active = true
                    ANIMATION.type = .Move
                    ANIMATION.start = get_time()
                    ANIMATION.duration = 500
                    ANIMATION.from = SELECTED_CELL
                    ANIMATION.to = HOVERING_CELL
                }
                if BOARD.cells[HOVERING_CELL.x][HOVERING_CELL.y].type == .Elemental &&
                   BOARD.cells[SELECTED_CELL.x][SELECTED_CELL.y].type == .Elemental {
                    ANIMATION.active = true
                    ANIMATION.type = .Attack
                    ANIMATION.start = get_time()
                    ANIMATION.duration = 300
                    ANIMATION.from = SELECTED_CELL
                    ANIMATION.to = HOVERING_CELL
                }
            }

            if !ANIMATION.active {
                if equal(SELECTED_CELL[:], HOVERING_CELL[:]) {
                    SELECTED_CELL = {-1,-1}
                } else {
                    SELECTED_CELL = HOVERING_CELL
                }
            }
        }
        // }}}

        // {{{ DEBUG INFO
        debug_info : [2]string
        if DRAW_BOARD && valid(SELECTED_CELL) {
            debug_info[0] = fmt.tprintf("Selected: %v", SELECTED_CELL)
            if BOARD.cells[SELECTED_CELL.x][SELECTED_CELL.y].type == .Elemental {
                debug_info[0] = fmt.tprintf("%v %v", debug_info[0], BOARD.cells[SELECTED_CELL.x][SELECTED_CELL.y].data)
            } else {
                debug_info[0] = fmt.tprintf("%v %v", debug_info[0], BOARD.cells[SELECTED_CELL.x][SELECTED_CELL.y].type)
            }
        }
        if DRAW_BOARD && valid(HOVERING_CELL) {
            debug_info[1] = fmt.tprintf("Hovering: %v", HOVERING_CELL)
            if BOARD.cells[HOVERING_CELL.x][HOVERING_CELL.y].type == .Elemental {
                debug_info[1] = fmt.tprintf("%v %v", debug_info[1], BOARD.cells[HOVERING_CELL.x][HOVERING_CELL.y].data)
            } else {
                debug_info[1] = fmt.tprintf("%v %v", debug_info[1], BOARD.cells[HOVERING_CELL.x][HOVERING_CELL.y].type)
            }
        }
        // }}}

        // {{{ SHADERS are awesome
        when ENABLED_SHADERS {
            for i in 0..<ALL_BOXES_INDEX {
                shader_add_box(shader, ALL_BOXES[i], i)
            }
            num_boxes := ALL_BOXES_INDEX * 2
            rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "num_boxes"), &num_boxes, .INT)
            ALL_BOXES_INDEX = 0
            ALL_BOXES := [MAX_BOXES]Box{}

            rl.SetShaderValue(shader, shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW], raw_data(CAMERA.position[:]), .VEC3)
            // rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "plane_height"), &PLANE_HEIGHT, .FLOAT)
            time := f32(rl.GetTime())
            rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "time"), &time, .FLOAT)

            resolution := [2]f32{ f32(rl.GetRenderWidth()), f32(rl.GetRenderHeight()) }
            rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "resolution"), raw_data(resolution[:]), .VEC2)

            window_position := ([2]f32)(rl.GetWindowPosition())
            rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "window_position"), raw_data(window_position[:]), .VEC2)
        }
        // }}}

        // {{{ Draw Calls
        rl.BeginDrawing(); {
            rl.ClearBackground({0,0,0,255})

            rl.BeginMode3D(CAMERA); {
                when ENABLED_SHADERS { rl.BeginShaderMode(shader) }
                // rl.DrawPlane({0, PLANE_HEIGHT, 0}, {100, 100}, BLACK)
                rl.DrawCubeV( {-50,0,0}, {0.01,1,1}*100, BLACK) //{0,255,255,255} )
                rl.DrawCubeV( {0,-50,0}, {1,0.01,1}*100, BLACK) //{255,0,255,255} )
                rl.DrawCubeV( {0,0,-50}, {1,1,0.01}*100, BLACK) //{255,255,0,255} )
                rl.DrawCubeV( {50,0,0},  {0.01,1,1}*100, BLACK) //{255,0,0,255} )
                rl.DrawCubeV( {0,50,0},  {1,0.01,1}*100, BLACK) //{0,255,0,255} )
                rl.DrawCubeV( {0,0,50},  {1,1,0.01}*100, BLACK) //{0,0,255,255} )

                if DRAW_BOARD { draw_board(&BOARD) }

                when ENABLED_SHADERS { rl.EndShaderMode(); }

                if DRAW_BOARD {
                    draw_all_elemental_wires(&BOARD)
                    draw_all_healths(&BOARD)
                }

                // rl.DrawLine3D({0,2,0}, {0,2,0} + {1,0,0}, {255, 0, 0, 255})
                // rl.DrawLine3D({0,2,0}, {0,2,0} + {0,1,0}, {0, 255, 0, 255})
                // rl.DrawLine3D({0,2,0}, {0,2,0} + {0,0,1}, {0, 0, 255, 255})
            }; rl.EndMode3D()

            for ostr, i in debug_info[:] {
                cstr := strings.clone_to_cstring(ostr)
                defer delete(cstr)
                rl.DrawText(cstr, 20, 20 + 40*i32(i), 20, rl.RAYWHITE)
            }

            if DRAW_BOARD { rl.DrawFPS(0,0) }
        }; rl.EndDrawing()
        // }}}
    }
    // }}}
    // }}}
}
