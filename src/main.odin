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

Spell :: enum { FS, HV, AF, DT, MS }

Box :: struct {
    pos: Vec3,
    size: Vec3,
}

ElementColor := [Element][2]Color{
	.Air    = { TW(.CYAN5   ), TW(.SKY3    ) }, // {{ 0x06, 0xB6, 0xD4, 0xFF }, { 0x7D, 0xD3, 0xFC, 0xFF }},
    .Fire   = { TW(.ORANGE4 ), TW(.RED6    ) }, // {{ 0xFB, 0x92, 0x3C, 0xFF }, { 0xDC, 0x26, 0x26, 0xFF }},
	.Rock   = { TW(.ZINC5   ), TW(.ZINC7   ) }, // {{ 0x71, 0x71, 0x7A, 0xFF }, { 0x3F, 0x3F, 0x46, 0xFF }},
	.Water  = { TW(.SKY5    ), TW(.BLUE6   ) }, // {{ 0x0E, 0xA5, 0xE9, 0xFF }, { 0x25, 0x63, 0xEB, 0xFF }},
	.Nature = { TW(.GREEN5  ), TW(.TEAL6   ) }, // {{ 0x22, 0xC5, 0x5E, 0xFF }, { 0x0D, 0x94, 0x88, 0xFF }},
	.Energy = { TW(.FUCHSIA5), TW(.VIOLET7 ) }, // {{ 0xD9, 0x46, 0xEF, 0xFF }, { 0x6D, 0x28, 0xD9, 0xFF }},
}
Element :: enum { Air, Fire, Rock, Water, Nature, Energy }
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
        shader := rl.LoadShader("src/resources/vertex.glsl", "src/resources/fragment.glsl")
        defer rl.UnloadShader(shader)
        shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW] = rl.GetShaderLocation(shader, "viewPos");
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
        if !ANIMATION.active && key == .P { DRAW_BOARD = !DRAW_BOARD }

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
        if valid(SELECTED_CELL) {
            debug_info[0] = fmt.tprintf("Selected: %v", SELECTED_CELL)
            if BOARD.cells[SELECTED_CELL.x][SELECTED_CELL.y].type == .Elemental {
                debug_info[0] = fmt.tprintf("%v %v", debug_info[0], BOARD.cells[SELECTED_CELL.x][SELECTED_CELL.y].data)
            } else {
                debug_info[0] = fmt.tprintf("%v %v", debug_info[0], BOARD.cells[SELECTED_CELL.x][SELECTED_CELL.y].type)
            }
        }
        if valid(HOVERING_CELL) {
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
        }
        // }}}

        // {{{ Draw Calls
        rl.BeginDrawing(); {
            rl.ClearBackground({0,0,0,255})

            rl.BeginMode3D(CAMERA); {
                when ENABLED_SHADERS { rl.BeginShaderMode(shader) }
                // rl.DrawPlane({0, PLANE_HEIGHT, 0}, {100, 100}, BLACK)
                rl.DrawCubeV( {-50,0,0}, {0.01,1,1}*100, {0,255,255,255} )
                rl.DrawCubeV( {0,-50,0}, {1,0.01,1}*100, {255,0,255,255} )
                rl.DrawCubeV( {0,0,-50}, {1,1,0.01}*100, {255,255,0,255} )
                rl.DrawCubeV( {50,0,0}, {0.01,1,1}*100, {255,0,0,255} )
                rl.DrawCubeV( {0,50,0}, {1,0.01,1}*100, {0,255,0,255} )
                rl.DrawCubeV( {0,0,50}, {1,1,0.01}*100, {0,0,255,255} )
                if DRAW_BOARD {
                    draw_board(&BOARD)
                }
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

            rl.DrawFPS(0,0)
        }; rl.EndDrawing()
        // }}}
    }
    // }}}
    // }}}
}

merge_board :: proc(board: ^Board) {
    // {{{
    merge_configurations := [8][3][2]int{
        {{-1, -1}, {+0, -1}, {+1, -1}},
        {{-1, +0}, {+0, +0}, {+1, +0}},
        {{-1, +1}, {+0, +1}, {+1, +1}},
        {{-1, -1}, {-1, +0}, {-1, +1}},
        {{+0, -1}, {+0, +0}, {+0, +1}},
        {{+1, -1}, {+1, +0}, {+1, +1}},
        {{-1, -1}, {+0, +0}, {+1, +1}},
        {{+1, -1}, {+0, +0}, {-1, +1}},
    }
    // }}}
}

new_board :: proc() -> (board: Board) {
    // {{{
    levels := [?]int{1, 2, 3}
    for i in 0..<12 {
        for j in 0..<12 {
            tile_color : Color = {0, 0, 0, 255}
            tile_blue := j >= 6
            tile_dark := (i+j) % 2 == 0
            if  tile_blue &&  tile_dark { tile_color = TW(.BLUE5) } // TW(.INDIGO7) }
            if  tile_blue && !tile_dark { tile_color = TW(.BLUE4) } // TW(.INDIGO6) }
            if !tile_blue &&  tile_dark { tile_color = TW(.GREEN5) } // TW(.YELLOW6) }
            if !tile_blue && !tile_dark { tile_color = TW(.GREEN4) } // TW(.YELLOW5) }
            tile_color.rgb = tile_color.rgb/16 * 10
            board.tiles[i][j].color = tile_color
            board.tiles[i][j].player = PlayerType(j/6)

            r := rand.float32()
            switch {
            case r < 0.25: {
                type := rand.choice_enum(Element)
                level := rand.choice(levels[:])
                health := 1 + int(rand.int31()) % HEALTH_LEVEL[level]
                board.cells[i][j].data = Elemental{ type, level, health }
                board.cells[i][j].type = .Elemental
                board.cells[i][j].aabb = get_cell_aabb(i, j, level)
            }
            // case r < 0.5: { board.cells[i][j].data = Block{} }
            }
        }
    }

    return
    // }}}
}

draw_board :: proc(board: ^Board) {
    // {{{
    for i in 0..<12 {
        for j in 0..<12 {
            tile := board.tiles[i][j]
            tile_aabb := get_tile_aabb(i,j)
            draw_cube(tile_aabb, tile.color)
        }
    }

    for i in 0..<12 {
        for j in 0..<12 {
            switch board.cells[i][j].type {
            case .Empty: continue
            case .Block: panic("\n\tTODO: implement Block rendering")
            case .Elemental: draw_elemental(board.cells[i][j].aabb, board.cells[i][j].data)
            }
        }
    }
    // }}}
}

draw_elemental :: proc(aabb: Box, data: Elemental) {
    // {{{
    BUMP : f32 : 0.05
    draw_cube(aabb, ElementColor[data.type][1], true)

    // draw_health(aabb, data)

    dot : Box
    for i in 0..<data.level {
        for j in 0..<data.level {
            dot.pos.x = (aabb.pos.x - aabb.size.x/2) + aabb.size.x / f32(data.level) * (f32(j) + 0.5)
            dot.pos.y = aabb.pos.y + aabb.size.y/2 + BUMP/4
            dot.pos.z = (aabb.pos.z - aabb.size.z/2) + aabb.size.z / f32(data.level) * (f32(i) + 0.5)

            dot.size = aabb.size * 0.75 / f32(data.level)
            dot.size.y = BUMP

            draw_cube(dot, ElementColor[data.type][0])
        }
    }
    // }}}
}

draw_elemental_wires :: proc(aabb: Box, data: Elemental) {
    // {{{
    BUMP : f32 : 0.05
    draw_cube_wires(aabb, ElementColor[data.type][0])

    // draw_health(aabb, data)

    dot : Box
    for i in 0..<data.level {
        for j in 0..<data.level {
            dot.pos.x = (aabb.pos.x - aabb.size.x/2) + aabb.size.x / f32(data.level) * (f32(j) + 0.5)
            dot.pos.y = aabb.pos.y + aabb.size.y/2 + BUMP/4
            dot.pos.z = (aabb.pos.z - aabb.size.z/2) + aabb.size.z / f32(data.level) * (f32(i) + 0.5)

            dot.size = aabb.size * 0.75 / f32(data.level)
            dot.size.y = BUMP

            draw_cube_wires(dot, ElementColor[data.type][1])
        }
    }
    // }}}
}

draw_all_elemental_wires :: proc(board: ^Board) {
    // {{{
    for i in 0..<12 {
        for j in 0..<12 {
            if board.cells[i][j].type != .Elemental { continue }
            draw_elemental_wires(board.cells[i][j].aabb, board.cells[i][j].data)
        }
    }
    // }}}
}

draw_all_healths :: proc(board: ^Board) {
    // {{{
    for i in 0..<12 {
        for j in 0..<12 {
            if board.cells[i][j].type != .Elemental { continue }
            draw_health(board.cells[i][j].aabb, board.cells[i][j].data)
        }
    }
    // }}}
}

draw_health :: proc(aabb: Box, data: Elemental, damage: int = 0, _reverse := true) {
    // {{{
    assert(data.level >= 1 && data.level <= 3)
    hp_max := HEALTH_LEVEL[data.level]
    hp_width := get_cell_size(3).x * 0.75 / 6
    hp_gap := (aabb.size.z - hp_width * f32(hp_max)) / (f32(hp_max) + 1)
    hp_depth : f32 = 0.025
    for i in 0..<hp_max {
        hp : Box
        hp.size = { hp_width, hp_width, hp_depth }
        hp.pos.x = aabb.pos.x + (-aabb.size.x/2 + hp_gap + hp_width/2 + f32(i)*(hp_gap + hp_width)) * (_reverse ? -1 : 1)
        hp.pos.y = aabb.pos.y
        hp.pos.z = aabb.pos.z + aabb.size.z/2 * (_reverse ? -1 : 1)

        empty := i >= data.health
        damaged := i >= data.health-damage

        draw_cube(hp, empty ? TW(.SLATE5) : damaged ? TW(.RED5) : TW(.YELLOW4))
        draw_cube_wires(hp, BLACK)
    }

    if _reverse { draw_health(aabb, data, damage, false) }
    // }}}
}

draw_cube :: proc { draw_cube_Vec3, draw_cube_Box }
draw_cube_wires :: proc { draw_cube_wires_Vec3, draw_cube_wires_Box }
draw_cube_Vec3 :: proc(pos, size: Vec3, color: Color, send_to_shader: bool = false) {
    when ENABLED_SHADERS {
        if send_to_shader {
            ALL_BOXES[ALL_BOXES_INDEX] = Box{pos, size}
            ALL_BOXES_INDEX += 1
        }
    }
    rl.DrawCubeV(pos, size, color)
}
draw_cube_wires_Vec3 :: proc(pos, size: Vec3, color: Color) { rl.DrawCubeWiresV(pos, size, color) }
draw_cube_Box :: proc(aabb: Box, color: Color, send_to_shader: bool = false) {
    when ENABLED_SHADERS {
        if send_to_shader {
            ALL_BOXES[ALL_BOXES_INDEX] = aabb
            ALL_BOXES_INDEX += 1
        }
    }
    rl.DrawCubeV(aabb.pos, aabb.size, color)
}
draw_cube_wires_Box :: proc(aabb: Box, color: Color) { rl.DrawCubeWiresV(aabb.pos, aabb.size, color) }

get_cell_aabb :: proc { get_cell_aabb_ij, get_cell_aabb_2int }
get_cell_aabb_ij :: proc(i, j, level: int) -> Box {
    cell_pos := get_cell_pos(i, j, level)
    cell_size := get_cell_size(level)
    return { cell_pos, cell_size }
}
get_cell_aabb_2int :: proc(pos: [2]int, level: int) -> Box {
    cell_pos := get_cell_pos(pos.x, pos.y, level)
    cell_size := get_cell_size(level)
    return { cell_pos, cell_size }
}

get_tile_aabb :: proc(i, j: int) -> Box {
    tile_height :: 0.01
    tile_pos := Vec3{f32(i), -tile_height/2, f32(j)} + {-5.5, 0, -5.5}
    tile_size := Vec3{1, tile_height, 1}
    return { tile_pos, tile_size }
}

raytrace :: proc(min_bound, max_bound: Vec3) -> rl.RayCollision {
    return rl.GetRayCollisionBox(rl.GetScreenToWorldRay(rl.GetMousePosition(), CAMERA), {min_bound, max_bound})
}

point2grid :: proc(point: Vec3) -> (i, j: int) {
    p := floor(point)
    i = math.clamp(int(p.x) + 6, 0, 11)
    j = math.clamp(int(p.z) + 6, 0, 11)
    return
}

lerp :: proc{ math.lerp, lerp_Vec3 }
lerp_Vec3 :: proc(a, b: Vec3, t: f32) -> Vec3 { return a * (1 - t) + b * t }

smootherstep :: proc(x: f32) -> f32 { return x * x * x * (x * (6 * x - 15) + 10) }

floor :: proc{ floor_Vec3 }
floor_Vec3 :: proc(v: Vec3) -> Vec3 { return { math.floor(v.x), math.floor(v.y), math.floor(v.z) } }

equal :: proc { equal_Vec3, equal_Box, equal_Array }
equal_Box :: proc(a, b: Box) -> bool {
    return equal(a.pos, b.pos) && equal(a.size, b.size)
}
equal_Array :: proc(a, b: $T/[]$E) -> bool where intrinsics.type_is_numeric(E) {
    for i in 0..<len(a) {
        if math.abs(f32(a[i]) - f32(b[i])) > EPSILON {
            return false
        }
    }
    return true
}
equal_Vec3 :: proc(a, b: Vec3) -> bool {
    return math.abs(a.x - b.x) <= EPSILON &&
           math.abs(a.y - b.y) <= EPSILON &&
           math.abs(a.z - b.z) <= EPSILON
}
equal_floor :: proc(a, b: Vec3) -> bool {
    return math.abs(math.floor(a.x) - math.floor(b.x)) <= EPSILON &&
           math.abs(math.floor(a.y) - math.floor(b.y)) <= EPSILON &&
           math.abs(math.floor(a.z) - math.floor(b.z)) <= EPSILON
}

valid :: proc(grid_pos: [2]int) -> bool {
    return grid_pos.x != -1 && grid_pos.y != -1 &&
           grid_pos.x >=  0 && grid_pos.y <= 11 &&
           grid_pos.x >=  0 && grid_pos.y <= 11
}

rotate_camera :: proc(direction: int) {
    // {{{
    radius : f32 = 6 * math.SQRT_TWO
    CAMERA.position.x /= radius
    CAMERA.position.z /= radius
    alpha := math.atan2(CAMERA.position.z, CAMERA.position.x)
    beta := alpha + f32(direction) * math.PI / 90
    beta -= math.mod(beta, math.PI / 90)
    CAMERA.position.x = math.cos(beta) * radius
    CAMERA.position.z = math.sin(beta) * radius
    // }}}
}

get_time :: proc() -> f32 {
    return f32(rl.GetTime()) * 1000
}

get_cell_size :: proc(level := 1) -> Vec3 { return {1, 0.75, 1} * 0.5 * math.pow(f32(level), 0.2) }
get_cell_pos :: proc(i,j: int, level := 1) -> Vec3 {
    return {
        f32(i-6)+0.5,
        get_cell_size(level).y / 2,
        f32(j-6)+0.5,
    }
}

shader_add_box :: proc(shader: rl.Shader, box: Box, index: int) {
    // {{{
    if index*2+1 >= MAX_BOXES { return }

    if box.pos.x < -6 || box.pos.x > 6 ||
       box.pos.y < -1 || box.pos.y > 1 ||
       box.pos.z < -6 || box.pos.z > 6 ||
       box.size.x < 0 || box.size.x > 2 ||
       box.size.y < 0 || box.size.y > 2 ||
       box.size.z < 0 || box.size.z > 2 {
        fmt.println(box)
    }

    pos_loc_cstr  := strings.clone_to_cstring(fmt.tprintf("boxes[%v]", index*2 + 0))
    size_loc_cstr := strings.clone_to_cstring(fmt.tprintf("boxes[%v]", index*2 + 1))
    defer delete(pos_loc_cstr)
    defer delete(size_loc_cstr)

    pos_loc  := rl.GetShaderLocation(shader, pos_loc_cstr)
    size_loc := rl.GetShaderLocation(shader, size_loc_cstr)

    pos  := box.pos;  rl.SetShaderValue(shader, pos_loc,  raw_data(pos[:]),  .VEC3)
    size := box.size; rl.SetShaderValue(shader, size_loc, raw_data(size[:]), .VEC3)
    // }}}
}
