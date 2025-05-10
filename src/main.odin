package elementals

import "core:fmt"
import "core:strings"
import "core:math"
import "core:math/linalg"
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
// ALL_BOXES_INDEX := 0
// ALL_BOXES : [MAX_BOXES]Box

DRAW_BOARD := true

VERTEX_SHADER :: #load("resources/vertex.glsl", cstring)
FRAGMENT_SHADER :: #load("resources/fragment.glsl", cstring)

ViewTarget :: enum { Game, Menu, Conf }
VIEW_TARGET : ViewTarget = .Menu

Spell :: enum { FS, HV, AF, DT, MS }

Box :: struct {
    pos: Vec3,
    size: Vec3,
}

ElementColor := [Element][2]Color{
    .Invalid  = { {0,0,0,255}, {255,0,255,255} },
    .Air    = { TW(.CYAN5   ), TW(.SKY3    ) }, // {{ 0x06, 0xB6, 0xD4, 0xFF }, { 0x7D, 0xD3, 0xFC, 0xFF }},
    .Fire   = { TW(.ORANGE4 ), TW(.RED6    ) }, // {{ 0xFB, 0x92, 0x3C, 0xFF }, { 0xDC, 0x26, 0x26, 0xFF }},
    .Rock   = { TW(.ZINC5   ), TW(.ZINC7   ) }, // {{ 0x71, 0x71, 0x7A, 0xFF }, { 0x3F, 0x3F, 0x46, 0xFF }},
    .Water  = { TW(.SKY5    ), TW(.BLUE6   ) }, // {{ 0x0E, 0xA5, 0xE9, 0xFF }, { 0x25, 0x63, 0xEB, 0xFF }},
    .Nature = { TW(.GREEN5  ), TW(.TEAL6   ) }, // {{ 0x22, 0xC5, 0x5E, 0xFF }, { 0x0D, 0x94, 0x88, 0xFF }},
    .Energy = { TW(.FUCHSIA5), TW(.VIOLET7 ) }, // {{ 0xD9, 0x46, 0xEF, 0xFF }, { 0x6D, 0x28, 0xD9, 0xFF }},
}
Element :: enum { Invalid, Air, Fire, Rock, Water, Nature, Energy }
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
BOARD : Board

ActionType :: enum { Move, Attack, Spell, Skip }
Action :: struct {
    type: ActionType,
}

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
ATTACK_FIREBALL_POS : Vec3
ATTACK_FIREBALL_COLOR : [2]Color

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

        render_state := 0 // nothing
        render_state |= 1 // flat color
        // render_state |= 2 // shadows
        // render_state |= 4 // background
        rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "render_state"), &render_state, .INT)
    }

    BOARD = new_board()
    // }}}

    // {{{ The Game Loop
    quit := false
    for !rl.WindowShouldClose() && !quit {
        // {{{ Collision Calculation
        COLLISION = rl.RayCollision{ distance = math.F32_MAX }
        if VIEW_TARGET == .Game {
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
        }
        // }}}

        // {{{ Animations + Logic
        if ANIMATION.active {
            switch ANIMATION.type {
            case .Move: {
                cell_from := &BOARD.cells[ANIMATION.from.x][ANIMATION.from.y]
                data_from, aabb_from := cell_info(ANIMATION.from, .Elemental) or_break

                cell_to := &BOARD.cells[ANIMATION.to.x][ANIMATION.to.y]
                _, aabb_to := cell_info(ANIMATION.to, .Empty) or_break

                t := math.unlerp(ANIMATION.start, ANIMATION.start+ANIMATION.duration, get_time())
                t = ease.cubic_in_out(t)
                if t >= 0 && t <= 1 {
                    cell_from.aabb.pos = math.lerp(aabb_from.pos, aabb_to.pos, t)
                } else {
                    cell_to^ = cell_from^
                    cell_to.aabb = get_cell_aabb(ANIMATION.to, data_from.level)
                    cell_from^ = Cell{ type = .Empty }
                    ANIMATION.active = false
                    ANIMATION.start = 0
                    ANIMATION.from = -1
                    ANIMATION.to = -1
                }
            }
            case .Attack: {
                cell_from := &BOARD.cells[ANIMATION.from.x][ANIMATION.from.y]
                data_from, aabb_from := cell_info(ANIMATION.from, .Elemental) or_break

                cell_to := &BOARD.cells[ANIMATION.to.x][ANIMATION.to.y]
                data_to, aabb_to := cell_info(ANIMATION.to, .Elemental) or_break

                ATTACK_FIREBALL_COLOR = ElementColor[data_from.type]

                t := math.unlerp(ANIMATION.start, ANIMATION.start+ANIMATION.duration, get_time())
                if t >= 0 && t <= 1 {
                    ATTACK_FIREBALL_POS = math.lerp(aabb_from.pos, aabb_to.pos, t)
                    ATTACK_FIREBALL_POS.y = math.sqrt(linalg.length(aabb_from.pos.xz - aabb_to.pos.xz)) * (-4 * t * t + 4 * t)
                } else {
                    cell_to.data.health = math.clamp(data_to.health - DAMAGE_LEVEL[data_from.level], 0, HEALTH_LEVEL[data_to.level])
                    if cell_to.data.health == 0 {
                        cell_to.data.level -= 1
                        if cell_to.data.level == 0 {
                            BOARD.cells[ANIMATION.to.x][ANIMATION.to.y] = Cell{}
                        } else {
                            cell_to.data.health = HEALTH_LEVEL[data_to.level]
                            cell_to.aabb.size = get_cell_size(data_to.level)
                        }
                    }
                    SELECTED_CELL = {-1,-1}
                    ANIMATION.active = false
                    ANIMATION.start = 0
                    ANIMATION.from = -1
                    ANIMATION.to = -1
                    ATTACK_FIREBALL_POS = {}
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
        switch {
        case key == .Q && !ANIMATION.active: { BOARD = new_board() }
        case key == .W: { DRAW_BOARD = !DRAW_BOARD }
        case key == .E: {
            when ENABLED_SHADERS {
                t1 := tw.TW_RANDOM()
                c1 := [3]f32{ f32(t1.r) / 255.0, f32(t1.g) / 255.0, f32(t1.b) / 255.0 }
                rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "bg_color_1"), raw_data(c1[:]), .VEC3)

                t2 := tw.TW_RANDOM()
                c2 := [3]f32{ f32(t2.r) / 255.0, f32(t2.g) / 255.0, f32(t2.b) / 255.0 }
                rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "bg_color_2"), raw_data(c2[:]), .VEC3)
            }
        }
        case key == .R: { VIEW_TARGET = .Menu }// ViewTarget((int(VIEW_TARGET)+1) % len(ViewTarget)) }
        }

        if VIEW_TARGET == .Game && !ANIMATION.active && rl.IsMouseButtonPressed(.LEFT) && COLLISION.hit {
            if valid(SELECTED_CELL) && valid(HOVERING_CELL) && !equal(SELECTED_CELL[:], HOVERING_CELL[:]) {
                if BOARD.cells[HOVERING_CELL.x][HOVERING_CELL.y].type == .Empty &&
                   BOARD.cells[SELECTED_CELL.x][SELECTED_CELL.y].type == .Elemental {
                    ANIMATION.active = true
                    ANIMATION.type = .Move
                    ANIMATION.start = get_time()
                    ANIMATION.duration = 1000
                    ANIMATION.from = SELECTED_CELL
                    ANIMATION.to = HOVERING_CELL
                }
                if BOARD.cells[HOVERING_CELL.x][HOVERING_CELL.y].type == .Elemental &&
                   BOARD.cells[SELECTED_CELL.x][SELECTED_CELL.y].type == .Elemental {
                    ANIMATION.active = true
                    ANIMATION.type = .Attack
                    ANIMATION.start = get_time()
                    ANIMATION.duration = 1000
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
        debug_info : [3]string
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
        if DRAW_BOARD {
            debug_info[2] = fmt.tprintf("%#v", ANIMATION)
        }
        // }}}

        // {{{ SHADERS are awesome
        when ENABLED_SHADERS {
            for y in 0..<12 {
                for x in 0..<12 {
                    cell := BOARD.cells[y][x]
                    if cell.type == .Elemental {
                        shader_add_box(shader, cell.aabb, x + y * 12)
                    } else {
                        shader_add_box(shader, Box{}, x + y * 12)
                    }
                }
            }
            // num_boxes := ALL_BOXES_INDEX * 2
            // rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "num_boxes"), &num_boxes, .INT)
            // ALL_BOXES_INDEX = 0

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

            switch VIEW_TARGET {
            case .Game: {
                rl.BeginMode3D(CAMERA); {
                    when ENABLED_SHADERS { rl.BeginShaderMode(shader) }
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

                        if ATTACK_FIREBALL_POS != ([3]f32{0,0,0}) {
                            c := ATTACK_FIREBALL_COLOR
                            rl.DrawSphere(ATTACK_FIREBALL_POS, 0.15, c[0])
                            rl.DrawSphere(ATTACK_FIREBALL_POS, 0.25, { c[1].r, c[1].g, c[1].b, 127 })
                            // rl.DrawSphereWires(ATTACK_FIREBALL_POS, 0.26, 16, 16, ATTACK_FIREBALL_COLOR[1])
                        }
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
            }
            case .Menu: {
                bg_color :: Color{ 0x20, 0x20, 0x20, 255}
                rl.ClearBackground(bg_color)
                w := f32(rl.GetScreenWidth())
                h := f32(rl.GetScreenHeight())

                btn_size := [2]f32{500, 200}

                btn_pos_play := [2]f32{ w/2 - btn_size.x/2, h/2 - btn_size.y/2 - btn_size.y * 1.25 }
                btn_pos_conf := [2]f32{ w/2 - btn_size.x/2, h/2 - btn_size.y/2 }
                btn_pos_quit := [2]f32{ w/2 - btn_size.x/2, h/2 - btn_size.y/2 + btn_size.y * 1.25 }

                state_play, action_play := button({ btn_pos_play.x, btn_pos_play.y, btn_size.x, btn_size.y })
                state_conf, action_conf := button({ btn_pos_conf.x, btn_pos_conf.y, btn_size.x, btn_size.y })
                state_quit, action_quit := button({ btn_pos_quit.x, btn_pos_quit.y, btn_size.x, btn_size.y })

                text_play :: "Play";      text_play_size := measure_text(text_play)
                text_conf :: "Settings";  text_conf_size := measure_text(text_conf)
                text_quit :: "Quit";      text_quit_size := measure_text(text_quit)

                color_play_fg := [?]Color{ TW(.GREEN4), TW(.GREEN5), TW(.GREEN3) }
                color_conf_fg := [?]Color{  TW(.BLUE4),  TW(.BLUE5),  TW(.BLUE3) }
                color_quit_fg := [?]Color{   TW(.RED4),   TW(.RED5),   TW(.RED3) }

                color_play_bg := [?]Color{   TW(.TEAL8),   TW(.TEAL9),   TW(.TEAL7) }
                color_conf_bg := [?]Color{ TW(.INDIGO8), TW(.INDIGO9), TW(.INDIGO7) }
                color_quit_bg := [?]Color{   TW(.ROSE8),   TW(.ROSE9),   TW(.ROSE7) }

                rl.DrawRectangleV(btn_pos_play, btn_size, color_play_fg[state_play])
                rl.DrawRectangleV(btn_pos_play + 10, btn_size - 20, color_play_bg[state_play])
                rl.DrawText(text_play,
                    i32(btn_pos_play.x + btn_size.x/2 - text_play_size.x/2),
                    i32(btn_pos_play.y + btn_size.y/2 - text_play_size.y/2),
                    64, color_play_fg[state_play])

                rl.DrawRectangleV(btn_pos_conf, btn_size, color_conf_fg[state_conf])
                rl.DrawRectangleV(btn_pos_conf + 10, btn_size - 20, color_conf_bg[state_conf])
                rl.DrawText(text_conf,
                    i32(btn_pos_conf.x + btn_size.x/2 - text_conf_size.x/2),
                    i32(btn_pos_conf.y + btn_size.y/2 - text_conf_size.y/2),
                    64, color_conf_fg[state_conf])

                rl.DrawRectangleV(btn_pos_quit, btn_size, color_quit_fg[state_quit])
                rl.DrawRectangleV(btn_pos_quit + 10, btn_size - 20, color_quit_bg[state_quit])
                rl.DrawText(text_quit,
                    i32(btn_pos_quit.x + btn_size.x/2 - text_quit_size.x/2),
                    i32(btn_pos_quit.y + btn_size.y/2 - text_quit_size.y/2),
                    64, color_quit_fg[state_quit])

                switch {
                case action_play: VIEW_TARGET = .Game
                case action_conf: VIEW_TARGET = .Conf
                case action_quit: quit = true
                }
            }
            case .Conf: {
                rl.DrawText("Here be dragons", 100, 100, 64, TW(.ROSE5))
            }
            }

            rl.DrawFPS(0,0)
        }; rl.EndDrawing()
        // }}}
        defer free_all(context.temp_allocator)
    }
    // }}}
    // }}}
}
