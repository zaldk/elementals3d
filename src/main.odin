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

// {{{ Types, Constants and Globals
Vec3 :: rl.Vector3
Color :: rl.Color
TW :: tw.TW

BLACK :: Color{0,0,0,255}
WHITE :: Color{255,255,255,255}

GameMode :: enum { None, Singleplayer, Multiplayer }
MultiplayerMode :: enum { None, Local, Network }
GAME_PLAYER_ID := 0
SETTINGS := struct{
    game_mode : GameMode,
    multiplayer_mode : MultiplayerMode,
    volume : f32,
}{
    game_mode = .Multiplayer,
    multiplayer_mode = .Local,
    volume = 0.0,
}

ENABLED_SHADERS :: #config(SHADERS, false)
ENABLED_VR :: #config(VR, false)
DEBUG_INFO :: false

TARGET_FPS :: 120
EPSILON :: 0.001
HEALTH_LEVEL := [?]int{ -1, 1, 2, 6 }
DAMAGE_LEVEL := [?]int{ -1, 1, 2, 4 }
REACH_LEVEL  := [?]int{ -1, 3, 5, 7 }
SPELL_DAMAGE := [Spell]int{ .FS = 2, .HV = -1, .AF = 1, .DT = -1, .MS = 4,  .None = -1 }
SPELL_CHARGE := [Spell]int{ .FS = 4, .HV =  5, .AF = 7, .DT =  9, .MS = 10, .None = -1 }

CAMERA : rl.Camera3D
CAM_HEIGHT := 9 * math.sqrt(f32(8) / f32(7))

COLLISION := rl.RayCollision{ distance = math.F32_MAX }
SELECTED_CELL := [2]int{-1, -1}
HOVERING_CELL := [2]int{-1, -1}
UPDATE_HOVER := true
RESET_SELECTED := true

MAX_BOXES :: 1024
// ALL_BOXES_INDEX := 0
// ALL_BOXES : [MAX_BOXES]Box

DRAW_BOARD := true

SHADER : rl.Shader
VERTEX_SHADER :: #load("resources/vertex.glsl", cstring)
FRAGMENT_SHADER :: #load("resources/fragment.glsl", cstring)
DISTORTION_SHADER :: #load("resources/distortion.glsl", cstring)

ViewTarget :: enum { None, Game, Menu, Conf }
VIEW_TARGET : ViewTarget = .Menu

Box :: struct {
    pos: Vec3,
    size: Vec3,
}

ElementColor := [Element][2]Color{
    .None  = { {0,0,0,255}, {255,0,255,255} },
    .Air    = { TW(.CYAN5   ), TW(.SKY3    ) }, // {{ 0x06, 0xB6, 0xD4, 0xFF }, { 0x7D, 0xD3, 0xFC, 0xFF }},
    .Fire   = { TW(.ORANGE4 ), TW(.RED6    ) }, // {{ 0xFB, 0x92, 0x3C, 0xFF }, { 0xDC, 0x26, 0x26, 0xFF }},
    .Rock   = { TW(.ZINC5   ), TW(.ZINC7   ) }, // {{ 0x71, 0x71, 0x7A, 0xFF }, { 0x3F, 0x3F, 0x46, 0xFF }},
    .Water  = { TW(.SKY5    ), TW(.BLUE6   ) }, // {{ 0x0E, 0xA5, 0xE9, 0xFF }, { 0x25, 0x63, 0xEB, 0xFF }},
    .Nature = { TW(.GREEN5  ), TW(.TEAL6   ) }, // {{ 0x22, 0xC5, 0x5E, 0xFF }, { 0x0D, 0x94, 0x88, 0xFF }},
    .Energy = { TW(.FUCHSIA5), TW(.VIOLET7 ) }, // {{ 0xD9, 0x46, 0xEF, 0xFF }, { 0x6D, 0x28, 0xD9, 0xFF }},
}
Element :: enum byte { None, Air, Fire, Rock, Water, Nature, Energy }
Elemental :: struct {
    type: Element,
    level: int,
    health: int,
}
Block :: struct {}
Empty :: struct {}

CellType :: enum byte { None, Empty, Block, Elemental, }
Cell :: struct {
    aabb: Box,
    type: CellType,
    data: Elemental,
}

PlayerType :: enum byte { None, Blue, Green }
Player :: struct {
    type: PlayerType,
    charges: [len(Spell)]byte,
}

Tile :: struct {
    color: Color,
    player: PlayerType,
}

// y<6: Blue | y>=6: Green
Board :: struct {
    cells: [12][12]Cell,
    tiles: [12][12]Tile,
}

ActionType :: enum byte { None, Move, Attack, Spell, Skip }
Action :: struct {
    type: ActionType,
    pos: [2][2]int, // [from.xy, to.xy]
    spell: Spell,
}

Spell :: enum byte { None, FS, HV, AF, DT, MS }

GAME : Game
Game :: struct {
    board: Board,
    players: [2]Player,
    turn: int, // N%2==0: Blue | N%2==1: Green
    used_spell, used_move, used_attack: bool,
}

AnimationType :: enum byte { None, Move, Attack, Spell, Skip }
Animation :: struct {
    active, valid: bool,
    type: AnimationType,
    duration, start: f32, // ms
    pos: [2][2]int, // grid position [from, to]
    spell: Spell,
}
ANIM := Animation {
    active = false, valid = false,
    type = .None,
    duration = 1000, start = 0,
    pos = {{-1, -1}, {-1, -1}},
    spell = .None,
}
MOVE_PATH : [144]Direction
ATTACK_FIREBALL_POS : Vec3
ATTACK_FIREBALL_COLOR : [2]Color
TURN_COLOR_BLUE  :: [4]f32{ 0, 0, 1, 1 }
TURN_COLOR_GREEN :: [4]f32{ 0, 1, 0, 1 }
TURN_COLOR : Color = rl.ColorFromNormalized(TURN_COLOR_BLUE)

ATTACK_SOUND : rl.Sound
// }}}

/*
Game loop:

SPL > MOV > ATK | SKP
SPL | MOV > ATK | SKP
            ATK | SKP

SPL > MOV | ATK | SKP
MOV > ATK | SKP
ATK | SKP

*/
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

    // {{{ Audio
    rl.InitAudioDevice()
    defer rl.CloseAudioDevice()

    rl.SetMasterVolume(SETTINGS.volume)

    bg_music := rl.LoadMusicStream("src/resources/background_music.mp3")
    defer rl.UnloadMusicStream(bg_music)

    ATTACK_SOUND = rl.LoadSound("src/resources/attack.mp3")
    defer rl.UnloadSound(ATTACK_SOUND)

    rl.PlayMusicStream(bg_music)
    // rl.PauseAudioStream(bg_music)
    // }}}

    CAMERA.position = { -6, CAM_HEIGHT, -6 }
    CAMERA.target = { 0, 0, 0 }
    CAMERA.up = { 0, 1, 0 }
    CAMERA.fovy = 15
    CAMERA.projection = .ORTHOGRAPHIC

    when ENABLED_SHADERS {
        // {{{
        SHADER = rl.LoadShaderFromMemory(VERTEX_SHADER, FRAGMENT_SHADER)
        defer rl.UnloadShader(SHADER)
        SHADER.locs[rl.ShaderLocationIndex.VECTOR_VIEW] = rl.GetShaderLocation(SHADER, "viewPos");

        t1 := tw.TW_RANDOM()
        c1 := [3]f32{ f32(t1.r) / 255.0, f32(t1.g) / 255.0, f32(t1.b) / 255.0 }
        rl.SetShaderValue(SHADER, rl.GetShaderLocation(SHADER, "bg_color_1"), raw_data(c1[:]), .VEC3)

        t2 := tw.TW_RANDOM()
        c2 := [3]f32{ f32(t2.r) / 255.0, f32(t2.g) / 255.0, f32(t2.b) / 255.0 }
        rl.SetShaderValue(SHADER, rl.GetShaderLocation(SHADER, "bg_color_2"), raw_data(c2[:]), .VEC3)

        display_resolution := [2]f32{ f32(rl.GetMonitorWidth(rl.GetCurrentMonitor())), f32(rl.GetMonitorHeight(rl.GetCurrentMonitor())) }
        rl.SetShaderValue(SHADER, rl.GetShaderLocation(SHADER, "display_resolution"), raw_data(display_resolution[:]), .VEC2)

        render_state := 0 // nothing
        render_state |= 1 // flat color
        // render_state |= 2 // shadows // currently broken
        render_state |= 4 // background
        when ENABLED_VR {
            render_state = 1
        }
        rl.SetShaderValue(SHADER, rl.GetShaderLocation(SHADER, "render_state"), &render_state, .INT)
        // }}}
    }

    when ENABLED_VR {
        // {{{
        // from https://www.raylib.com/examples/core/loader.html?name=core_vr_simulator
        // VR device parameters definition
        device := rl.VrDeviceInfo {
            // Oculus Rift CV1 parameters for simulator
            hResolution = 2160,                 // Horizontal resolution in pixels
            vResolution = 1200,                 // Vertical resolution in pixels
            hScreenSize = 0.133793,            // Horizontal size in meters
            vScreenSize = 0.0669,              // Vertical size in meters
            eyeToScreenDistance = 0.041,       // Distance between eye and display in meters
            lensSeparationDistance = 0.07,     // Lens separation distance in meters
            interpupillaryDistance = 0.07,     // IPD (distance between pupils) in meters

            // NOTE: CV1 uses fresnel-hybrid-asymmetric lenses with specific compute shaders
            // Following parameters are just an approximation to CV1 distortion stereo rendering
            lensDistortionValues = { 1.0, 0.22, 0.24, 0 },      // Lens distortion constant parameter 0
            chromaAbCorrection = { 0.996, -0.004, 1.014, 0.0 }, // Chromatic aberration correction parameter 0
        }

        // Load VR stereo config for VR device parameteres (Oculus Rift CV1 parameters)
        config := rl.LoadVrStereoConfig(device)
        defer rl.UnloadVrStereoConfig(config)

        // Distortion shader (uses device lens distortion and chroma)
        distortion := rl.LoadShaderFromMemory(nil, DISTORTION_SHADER)
        defer rl.UnloadShader(distortion)

        // Update distortion shader with lens and distortion-scale parameters
        rl.SetShaderValue(distortion, rl.GetShaderLocation(distortion, "leftLensCenter"), raw_data(config.leftLensCenter[:]), .VEC2);
        rl.SetShaderValue(distortion, rl.GetShaderLocation(distortion, "rightLensCenter"), raw_data(config.rightLensCenter[:]), .VEC2);
        rl.SetShaderValue(distortion, rl.GetShaderLocation(distortion, "leftScreenCenter"), raw_data(config.leftScreenCenter[:]), .VEC2);
        rl.SetShaderValue(distortion, rl.GetShaderLocation(distortion, "rightScreenCenter"), raw_data(config.rightScreenCenter[:]), .VEC2);

        rl.SetShaderValue(distortion, rl.GetShaderLocation(distortion, "scale"), raw_data(config.scale[:]), .VEC2);
        rl.SetShaderValue(distortion, rl.GetShaderLocation(distortion, "scaleIn"), raw_data(config.scaleIn[:]), .VEC2);
        rl.SetShaderValue(distortion, rl.GetShaderLocation(distortion, "deviceWarpParam"), raw_data(device.lensDistortionValues[:]), .VEC4);
        rl.SetShaderValue(distortion, rl.GetShaderLocation(distortion, "chromaAbParam"), raw_data(device.chromaAbCorrection[:]), .VEC4);

        // Initialize framebuffer for stereo rendering
        // NOTE: Screen size should match HMD aspect ratio
        target := rl.LoadRenderTexture(device.hResolution, device.vResolution)
        defer rl.UnloadRenderTexture(target)

        // The target's height is flipped (in the source Rectangle), due to OpenGL reasons
        sourceRec := rl.Rectangle{ 0.0, 0.0, f32(target.texture.width), -f32(target.texture.height) }
        destRec   := rl.Rectangle{ 0.0, 0.0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()) }

        rl.HideCursor()
        // }}}
    }

    GAME.board = new_board()
    if SETTINGS.game_mode == .Multiplayer && SETTINGS.multiplayer_mode == .Network {
        if GAME_PLAYER_ID == 0 {
            write_board(GAME.board)
        } else {
            board, ok := read_board()
            if ok { GAME.board = board }
        }
    }
    // }}}

    // {{{ The Game Loop
    quit := false
    for !rl.WindowShouldClose() && !quit {
        // {{{ Audio
        rl.UpdateMusicStream(bg_music)
        // }}}

        // {{{ Collision Calculation
        COLLISION = rl.RayCollision{ distance = math.F32_MAX }
        if VIEW_TARGET == .Game {
            for i in 0..<12 {
                for j in 0..<12 {
                    tile := get_tile_aabb(i,j)
                    tile_collision := raytrace(tile.pos - tile.size/2, tile.pos + tile.size/2)

                    cell_collision := tile_collision
                    if GAME.board.cells[i][j].type == .Elemental {
                        cell := get_cell_aabb(i, j, GAME.board.cells[i][j].data.level)
                        cell_collision = raytrace(cell.pos - cell.size/2, cell.pos + cell.size/2)
                    }

                    switch {
                    case !tile_collision.hit && !cell_collision.hit:
                        continue

                    case !tile_collision.hit && cell_collision.hit:
                        if COLLISION.distance > cell_collision.distance { COLLISION = cell_collision }

                    case tile_collision.hit && !cell_collision.hit:
                        if COLLISION.distance > tile_collision.distance { COLLISION = tile_collision }

                    case tile_collision.hit && cell_collision.hit:
                        min_collision := tile_collision
                        if min_collision.distance > cell_collision.distance { min_collision = cell_collision }
                        if COLLISION.distance > min_collision.distance { COLLISION = min_collision }
                    }
                }
            }
        }
        // }}}

        // {{{ Animations + Logic Calls
        if ANIM.active {
            switch ANIM.type {
            case .Move:
                // {{{
                cell_A := &GAME.board.cells[ANIM.pos.x.x][ANIM.pos.x.y]
                data_A, aabb_A := cell_info(ANIM.pos.x, .Elemental) or_break

                cell_B := &GAME.board.cells[ANIM.pos.y.x][ANIM.pos.y.y]
                data_B, aabb_B := cell_info(ANIM.pos.y, .Empty) or_break

                ANIM.valid = true

                t := math.unlerp(ANIM.start, ANIM.start+ANIM.duration, get_time())
                if t >= 0 && t <= 1 {
                    t = ease.sine_in_out(t)
                    t_pos := get_path_pos(MOVE_PATH[:], aabb_A.pos, aabb_B.pos, t)
                    cell_A.aabb.pos = t_pos
                } else {
                    apply_action(&GAME, { type = .Move, pos = ANIM.pos })
                    if SETTINGS.game_mode == .Multiplayer { write_action({ type = .Move, pos = ANIM.pos }) }
                    ANIM = {}
                    ANIM.pos = -1
                    MOVE_PATH = {}
                    if !UPDATE_HOVER && RESET_SELECTED {
                        SELECTED_CELL = -1
                        HOVERING_CELL = -1
                        RESET_SELECTED = true
                    }
                    UPDATE_HOVER = true
                }
                // }}}
            case .Attack:
                // {{{
                cell_A := &GAME.board.cells[ANIM.pos.x.x][ANIM.pos.x.y]
                data_A, aabb_A := cell_info(ANIM.pos.x, .Elemental) or_break

                cell_B := &GAME.board.cells[ANIM.pos.y.x][ANIM.pos.y.y]
                data_B, aabb_B := cell_info(ANIM.pos.y, .Elemental) or_break

                ANIM.valid = true
                ATTACK_FIREBALL_COLOR = ElementColor[data_A.type]

                t := math.unlerp(ANIM.start, ANIM.start+ANIM.duration, get_time())
                if t >= 0 && t <= 1 {
                    ATTACK_FIREBALL_POS = math.lerp(aabb_A.pos, aabb_B.pos, t)
                    ATTACK_FIREBALL_POS.y = math.sqrt(linalg.length(aabb_A.pos.xz - aabb_B.pos.xz)) * (-4 * t * t + 4 * t)
                } else {
                    ok := apply_action(&GAME, { type = .Attack, pos = ANIM.pos })
                    if !ok {
                        ANIM = {}
                        ANIM.pos = -1
                        fmt.println("Failed attack")
                    } else {
                        if SETTINGS.game_mode == .Multiplayer { write_action({ type = .Attack, pos = ANIM.pos }) }
                    }
                    // no ANIM reset, as the apply_attack will set ANIM to skip
                    ATTACK_FIREBALL_POS = {}
                }
                // }}}
            case .Spell: panic("TODO")
            case .Skip:
                // {{{
                color_p1 := (GAME.turn&1 == 0) ? TURN_COLOR_BLUE : TURN_COLOR_GREEN
                color_p2 := (GAME.turn&1 == 1) ? TURN_COLOR_BLUE : TURN_COLOR_GREEN
                ANIM.valid = true
                t := math.unlerp(ANIM.start, ANIM.start+ANIM.duration, get_time())
                if t >= 0 && t <= 1 {
                    TURN_COLOR = rl.ColorFromNormalized(math.lerp(color_p1, color_p2, math.sqrt(t)))
                } else {
                    apply_action(&GAME, { type = .Skip })
                    if SETTINGS.game_mode == .Multiplayer { write_action({ type = .Skip }) }
                    ANIM = {}
                    ANIM.pos = -1
                }
                // }}}
            case .None: panic("How?")
            }
        }
        // }}}

        // {{{ Turn logic
        skip_input := false
        if SETTINGS.game_mode == .Singleplayer && !ANIM.active {
            if GAME.turn&1 == 1 {
                execute_ai()
            } else {
                if valid(SELECTED_CELL) && GAME.used_move && !can_attack(GAME.board, SELECTED_CELL) {
                    start_animation(.Skip)
                }
            }
        }
        if SETTINGS.game_mode == .Multiplayer && !ANIM.active && SETTINGS.multiplayer_mode == .Local {
            if valid(SELECTED_CELL) && GAME.used_move && !can_attack(GAME.board, SELECTED_CELL) {
                start_animation(.Skip)
            }
        }
        for SETTINGS.game_mode == .Multiplayer && GAME.turn&1 == 1-GAME_PLAYER_ID && !ANIM.active && SETTINGS.multiplayer_mode == .Network {
            if is_socket_empty(SOCK_ACTION) {
                skip_input = true
                break
            }

            act, ok := read_action()
            if !ok {
                skip_input = true
                break
            }

            fmt.println("Found this action:", act)

            switch act.type {
            case .Move:
                path, found := get_path(GAME.board, act.pos)
                if found {
                    MOVE_PATH = path
                    SELECTED_CELL = act.pos.x
                    HOVERING_CELL = act.pos.y
                    UPDATE_HOVER = false
                    start_animation(.Move, act.pos)
                }
            case .Attack: start_animation(.Attack, act.pos)
            case .Spell: fallthrough
            case .Skip: start_animation(.Skip)
            case .None: skip_input = true
            }

            clear_socket(SOCK_ACTION)
            break
        }
        // }}}

        // {{{ Input
        when !ENABLED_VR {
            if !rl.IsKeyDown(.LEFT_SHIFT) && rl.GetMouseWheelMoveV().y < 0 { CAMERA.fovy *= 1.1 }
            if !rl.IsKeyDown(.LEFT_SHIFT) && rl.GetMouseWheelMoveV().y > 0 { CAMERA.fovy *= 0.9 }
            if  rl.IsKeyDown(.LEFT_SHIFT) && rl.GetMouseWheelMoveV().y < 0 { rotate_camera(-1) }
            if  rl.IsKeyDown(.LEFT_SHIFT) && rl.GetMouseWheelMoveV().y > 0 { rotate_camera(+1) }
            if rl.GetMouseWheelMoveV().x < 0 { rotate_camera(-1) }
            if rl.GetMouseWheelMoveV().x > 0 { rotate_camera(+1) }
        } else {
            if rl.IsKeyDown(.LEFT_SHIFT) { CAMERA.position.y -= 0.05 }
            if rl.IsKeyDown(.SPACE)      { CAMERA.position.y += 0.05 }
        }

        if COLLISION.hit && UPDATE_HOVER {
            i, j := point2grid(COLLISION.point)
            HOVERING_CELL = {i,j}
            if GAME.board.cells[i][j].type == .Elemental {
                rl.SetMouseCursor(.POINTING_HAND)
            } else {
                rl.SetMouseCursor(.DEFAULT)
            }
        }

        key := rl.GetKeyPressed()
        switch {
        case key == .F1: VIEW_TARGET = .Menu
        case key == .F2 && !ANIM.active:
            GAME.board = new_board()
            MOVE_PATH = {}
            SELECTED_CELL = -1
        case key == .F3: DRAW_BOARD = !DRAW_BOARD
        case key == .F4:
            when ENABLED_SHADERS {
                t1 := tw.TW_RANDOM()
                c1 := [3]f32{ f32(t1.r) / 255.0, f32(t1.g) / 255.0, f32(t1.b) / 255.0 }
                rl.SetShaderValue(SHADER, rl.GetShaderLocation(SHADER, "bg_color_1"), raw_data(c1[:]), .VEC3)

                t2 := tw.TW_RANDOM()
                c2 := [3]f32{ f32(t2.r) / 255.0, f32(t2.g) / 255.0, f32(t2.b) / 255.0 }
                rl.SetShaderValue(SHADER, rl.GetShaderLocation(SHADER, "bg_color_2"), raw_data(c2[:]), .VEC3)
            }
        case key == .F5 && !ANIM.active: execute_ai()
        case key == .F6: if rl.IsCursorHidden() { rl.EnableCursor() } else { rl.DisableCursor() }
        case key == .F7:
            SETTINGS.volume = SETTINGS.volume == 0 ? 0.2 : 0
            rl.SetMasterVolume(SETTINGS.volume)

        case key == .ONE:   start_animation(.Spell, {}, Spell.FS)
        case key == .TWO:   start_animation(.Spell, {}, Spell.HV)
        case key == .THREE: start_animation(.Spell, {}, Spell.AF)
        case key == .FOUR:  start_animation(.Spell, {}, Spell.DT)
        case key == .FIVE:  start_animation(.Spell, {}, Spell.MS)
        }

        if VIEW_TARGET == .Game && !ANIM.active && !ANIM.valid && rl.IsMouseButtonPressed(.LEFT) && COLLISION.hit {
            unselect_active := true
            if valid(SELECTED_CELL) && valid(HOVERING_CELL) && !equal(SELECTED_CELL[:], HOVERING_CELL[:]) {
                // Move - Self-Self
                if !GAME.used_move &&
                  get_cell(GAME.board, SELECTED_CELL).type == .Elemental &&
                  get_cell(GAME.board, HOVERING_CELL).type == .Empty &&
                  get_player(SELECTED_CELL) == get_player(HOVERING_CELL) {
                    path, found := get_path(GAME.board, { SELECTED_CELL, HOVERING_CELL })
                    if found {
                        MOVE_PATH = path
                        start_animation(.Move, { SELECTED_CELL, HOVERING_CELL })
                    }
                }
                // Attack - Self-Enemy
                if get_cell(GAME.board, SELECTED_CELL).type == .Elemental &&
                   get_cell(GAME.board, HOVERING_CELL).type == .Elemental &&
                   get_player(SELECTED_CELL) != get_player(HOVERING_CELL) {
                    if SELECTED_CELL.y / 6 == HOVERING_CELL.y / 6 {
                        SELECTED_CELL = HOVERING_CELL
                        unselect_active = false
                    } else {
                        if is_attackable(SELECTED_CELL, HOVERING_CELL) {
                            start_animation(.Attack, { SELECTED_CELL, HOVERING_CELL })
                        }
                    }
                }
            }

            if !ANIM.active && unselect_active && !GAME.used_move {
                if equal(SELECTED_CELL[:], HOVERING_CELL[:]) {
                    SELECTED_CELL = {-1,-1} // double-click == unselect
                    MOVE_PATH = {}
                } else {
                    this_player := GAME.turn&1
                    if SETTINGS.game_mode == .Multiplayer {
                        this_player = GAME_PLAYER_ID == 0 ? this_player : 1 - this_player
                    }
                    if get_player(HOVERING_CELL) == PlayerType(this_player + 1) {
                        SELECTED_CELL = HOVERING_CELL
                        if get_cell(GAME.board, HOVERING_CELL).type != .Elemental {
                            MOVE_PATH = {}
                        }
                    }
                }
            }
        }

        if !GAME.used_move {
            if VIEW_TARGET == .Game && !(ANIM.active && ANIM.valid) && COLLISION.hit {
                if valid(SELECTED_CELL) && valid(HOVERING_CELL) && !equal(SELECTED_CELL[:], HOVERING_CELL[:]) {
                    if get_cell(GAME.board, HOVERING_CELL).type == .Empty &&
                    get_cell(GAME.board, SELECTED_CELL).type == .Elemental {
                        path, found := get_path(GAME.board, { SELECTED_CELL, HOVERING_CELL })
                        if found { MOVE_PATH = path } else { MOVE_PATH = {} }
                    }
                }
            }
        } else {
            MOVE_PATH = {}
        }

        // }}}

        // {{{ DEBUG INFO
        when DEBUG_INFO == true {
            debug_info : string
            if DRAW_BOARD && valid(SELECTED_CELL) {
                debug_info = fmt.tprintf("%v\nSelected: %v", debug_info, SELECTED_CELL)
                if GAME.board.cells[SELECTED_CELL.x][SELECTED_CELL.y].type == .Elemental {
                    debug_info = fmt.tprintf("%v %v", debug_info, GAME.board.cells[SELECTED_CELL.x][SELECTED_CELL.y].data)
                } else {
                    debug_info = fmt.tprintf("%v %v", debug_info, GAME.board.cells[SELECTED_CELL.x][SELECTED_CELL.y].type)
                }
            }
            if DRAW_BOARD && valid(HOVERING_CELL) {
                debug_info = fmt.tprintf("%v\nHovering: %v", debug_info, HOVERING_CELL)
                if GAME.board.cells[HOVERING_CELL.x][HOVERING_CELL.y].type == .Elemental {
                    debug_info = fmt.tprintf("%v %v", debug_info, GAME.board.cells[HOVERING_CELL.x][HOVERING_CELL.y].data)
                } else {
                    debug_info = fmt.tprintf("%v %v", debug_info, GAME.board.cells[HOVERING_CELL.x][HOVERING_CELL.y].type)
                }
            }
            // if DRAW_BOARD {
            //     used := [?]bool{GAME.used_spell, GAME.used_move, GAME.used_attack}
            //     debug_info = fmt.tprintf("%v\nGAME: turn: %v | used: %v | players: %v", debug_info, GAME.turn, used, GAME.players)
            //     debug_info = fmt.tprintf("%v\n%v - %#v", debug_info, ANIM, MOVE_PATH[:get_path_length(MOVE_PATH[:])])
            //     debug_info = fmt.tprintf("%v\n skip_input: %v", debug_info, skip_input)
            //     debug_info = fmt.tprintf("%v\n GAME_PLAYER_ID: %v", debug_info, GAME_PLAYER_ID)
            // }
        }
        // }}}

        // {{{ SHADERS are awesome
        when ENABLED_SHADERS {
            for y in 0..<12 {
                for x in 0..<12 {
                    cell := GAME.board.cells[y][x]
                    if cell.type == .Elemental {
                        shader_add_box(SHADER, cell.aabb, x + y * 12)
                    } else {
                        shader_add_box(SHADER, Box{}, x + y * 12)
                    }
                }
            }
            // num_boxes := ALL_BOXES_INDEX * 2
            // rl.SetShaderValue(SHADER, rl.GetShaderLocation(SHADER, "num_boxes"), &num_boxes, .INT)
            // ALL_BOXES_INDEX = 0

            rl.SetShaderValue(SHADER, SHADER.locs[rl.ShaderLocationIndex.VECTOR_VIEW], raw_data(CAMERA.position[:]), .VEC3)
            // rl.SetShaderValue(SHADER, rl.GetShaderLocation(SHADER, "plane_height"), &PLANE_HEIGHT, .FLOAT)
            time := f32(rl.GetTime())
            rl.SetShaderValue(SHADER, rl.GetShaderLocation(SHADER, "time"), &time, .FLOAT)

            resolution := [2]f32{ f32(rl.GetRenderWidth()), f32(rl.GetRenderHeight()) }
            rl.SetShaderValue(SHADER, rl.GetShaderLocation(SHADER, "resolution"), raw_data(resolution[:]), .VEC2)

            window_position := ([2]f32)(rl.GetWindowPosition())
            rl.SetShaderValue(SHADER, rl.GetShaderLocation(SHADER, "window_position"), raw_data(window_position[:]), .VEC2)
        }
        // }}}

        // {{{ Draw Calls
        _draw_3d_helper :: proc() {
            rl.BeginMode3D(CAMERA); {
                when ENABLED_SHADERS { rl.BeginShaderMode(SHADER) }
                rl.DrawCubeV( {-25,0,0}, {0.01,1,1}*50, BLACK) //{0,255,255,255} )
                rl.DrawCubeV( {0,-25,0}, {1,0.01,1}*50, BLACK) //{255,0,255,255} )
                rl.DrawCubeV( {0,0,-25}, {1,1,0.01}*50, BLACK) //{255,255,0,255} )
                rl.DrawCubeV( {25,0,0},  {0.01,1,1}*50, BLACK) //{255,0,0,255} )
                rl.DrawCubeV( {0,25,0},  {1,0.01,1}*50, BLACK) //{0,255,0,255} )
                rl.DrawCubeV( {0,0,25},  {1,1,0.01}*50, BLACK) //{0,0,255,255} )
                if DRAW_BOARD { draw_board(GAME.board) }
                when ENABLED_SHADERS { rl.EndShaderMode(); }

                if DRAW_BOARD {
                    draw_all_elemental_wires(GAME.board)
                    draw_all_healths(GAME.board)
                    if valid(HOVERING_CELL) { highlight_cell(HOVERING_CELL) }
                    if valid(SELECTED_CELL) { highlight_cell(SELECTED_CELL) }
                    if valid(SELECTED_CELL) && get_path_length(MOVE_PATH[:]) > 0 { draw_path(SELECTED_CELL, MOVE_PATH[:]) }
                    draw_attacked_tiles(GAME.board, SELECTED_CELL)

                    if ATTACK_FIREBALL_POS != ([3]f32{0,0,0}) {
                        c := ATTACK_FIREBALL_COLOR
                        rl.DrawSphere(ATTACK_FIREBALL_POS, 0.15, c[0])
                        rl.DrawSphere(ATTACK_FIREBALL_POS, 0.25, { c[1].r, c[1].g, c[1].b, 127 })
                    }
                    rl.DrawCubeV({  6, 0,  6 }, 0.2, TURN_COLOR)
                    rl.DrawCubeV({ -6, 0,  6 }, 0.2, TURN_COLOR)
                    rl.DrawCubeV({  6, 0, -6 }, 0.2, TURN_COLOR)
                    rl.DrawCubeV({ -6, 0, -6 }, 0.2, TURN_COLOR)
                }
            }; rl.EndMode3D()
        }
        switch VIEW_TARGET {
        case .Game: {
            when ENABLED_VR {
                if rl.IsCursorHidden() { rl.UpdateCamera(&CAMERA, .FIRST_PERSON) }
                rl.BeginVrStereoMode(config)
                rl.BeginTextureMode(target); {
                    rl.ClearBackground(WHITE);
                    rl.BeginVrStereoMode(config); {
                        _draw_3d_helper()
                        w1 : f32 = sourceRec.width/4
                        w2 : f32 = w1 + sourceRec.width/2
                        h  : f32 = -sourceRec.height
                        w  : f32 = 8.0
                        rl.DrawRectangleV({ w1 - w/2, h/2 }, {w,w}, WHITE)
                        rl.DrawRectangleV({ w2 - w/2, h/2 }, {w,w}, WHITE)
                    }; rl.EndVrStereoMode();
                }; rl.EndTextureMode();
            }
            rl.BeginDrawing(); {
                rl.ClearBackground({0,0,0,255})

                when ENABLED_VR {
                    rl.BeginShaderMode(distortion)
                    rl.DrawTexturePro(target.texture, sourceRec, destRec, { 0, 0 }, 0, WHITE)
                    rl.EndShaderMode()
                } else {
                    _draw_3d_helper()
                }

                when DEBUG_INFO == true {
                    cstr := strings.clone_to_cstring(debug_info)
                    defer delete(cstr)
                    rl.DrawText(cstr, 20, 20, 20, rl.RAYWHITE)
                    rl.DrawFPS(0,0)
                }
            }; rl.EndDrawing()
        }
        case .Menu: {
            if rl.IsCursorHidden() { rl.EnableCursor() }
            rl.BeginDrawing(); {
                rl.ClearBackground({0,0,0,255})

                bg_color :: Color{ 0x20, 0x20, 0x20, 255}
                rl.ClearBackground(bg_color)
                w := f32(rl.GetScreenWidth())
                h := f32(rl.GetScreenHeight())

                btn_size := [2]f32{500, 200}

                btn_pos_play_1 := [2]f32{ w/2 - btn_size.x/2, h/2 - btn_size.y/2 - btn_size.y * 1.75 }
                btn_pos_play_2 := [2]f32{ w/2 - btn_size.x/2, h/2 - btn_size.y/2 - btn_size.y * 0.575 }
                btn_pos_conf   := [2]f32{ w/2 - btn_size.x/2, h/2 - btn_size.y/2 + btn_size.y * 0.575 }
                btn_pos_quit   := [2]f32{ w/2 - btn_size.x/2, h/2 - btn_size.y/2 + btn_size.y * 1.75 }

                state_play_1, action_play_1 := button({ btn_pos_play_1.x, btn_pos_play_1.y, btn_size.x, btn_size.y })
                state_play_2, action_play_2 := button({ btn_pos_play_2.x, btn_pos_play_2.y, btn_size.x, btn_size.y })
                state_conf, action_conf := button({ btn_pos_conf.x, btn_pos_conf.y, btn_size.x, btn_size.y })
                state_quit, action_quit := button({ btn_pos_quit.x, btn_pos_quit.y, btn_size.x, btn_size.y })

                text_play_1 :: "PvE";     text_play_1_size := measure_text(text_play_1)
                text_play_2 :: "PvP";     text_play_2_size := measure_text(text_play_2)
                text_conf :: "Help";  text_conf_size := measure_text(text_conf)
                text_quit :: "Quit";      text_quit_size := measure_text(text_quit)

                color_play_1_fg := [?]Color{ TW(.GREEN4), TW(.GREEN5), TW(.GREEN3) }
                color_play_2_fg := [?]Color{ TW(.GREEN4), TW(.GREEN5), TW(.GREEN3) }
                color_conf_fg := [?]Color{  TW(.BLUE4),  TW(.BLUE5),  TW(.BLUE3) }
                color_quit_fg := [?]Color{   TW(.RED4),   TW(.RED5),   TW(.RED3) }

                color_play_1_bg := [?]Color{   TW(.TEAL8),   TW(.TEAL9),   TW(.TEAL7) }
                color_play_2_bg := [?]Color{   TW(.TEAL8),   TW(.TEAL9),   TW(.TEAL7) }
                color_conf_bg := [?]Color{ TW(.INDIGO8), TW(.INDIGO9), TW(.INDIGO7) }
                color_quit_bg := [?]Color{   TW(.ROSE8),   TW(.ROSE9),   TW(.ROSE7) }

                rl.DrawRectangleV(btn_pos_play_1, btn_size, color_play_1_fg[state_play_1])
                rl.DrawRectangleV(btn_pos_play_1 + 10, btn_size - 20, color_play_1_bg[state_play_1])
                rl.DrawText(text_play_1,
                    i32(btn_pos_play_1.x + btn_size.x/2 - text_play_1_size.x/2),
                    i32(btn_pos_play_1.y + btn_size.y/2 - text_play_1_size.y/2),
                    64, color_play_1_fg[state_play_1])

                rl.DrawRectangleV(btn_pos_play_2, btn_size, color_play_2_fg[state_play_2])
                rl.DrawRectangleV(btn_pos_play_2 + 10, btn_size - 20, color_play_2_bg[state_play_2])
                rl.DrawText(text_play_2,
                    i32(btn_pos_play_2.x + btn_size.x/2 - text_play_2_size.x/2),
                    i32(btn_pos_play_2.y + btn_size.y/2 - text_play_2_size.y/2),
                    64, color_play_2_fg[state_play_2])

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
                case action_play_1:
                    VIEW_TARGET = .Game
                    SETTINGS.game_mode = .Singleplayer
                case action_play_2:
                    VIEW_TARGET = .Game
                    SETTINGS.game_mode = .Multiplayer
                    SETTINGS.multiplayer_mode = .Local
                case action_conf: VIEW_TARGET = .Conf
                case action_quit: quit = true
                }
            }
        }; rl.EndDrawing()
        case .Conf: {
            rl.BeginDrawing(); {
                rl.ClearBackground({0,0,0,255})
                rl.DrawText("Here be dragons", 100, 100, 64, TW(.ROSE5))
                rl.DrawText("F1:  Open Menu\nF2: Regenerate the Board\nF3: Show/Hide the Board\nF4: Change Background Color Palette\nF5: AI game action\nF6: Hide Cursor\nF7: Mute audio", 100, 200, 64, TW(.SLATE3))
                // TODO:
                // audio mute
                // shaders
            }; rl.EndDrawing()
        }
        case .None: panic("How?")
        }
        // }}}
        defer free_all(context.temp_allocator)
    }
    // }}}

    if SETTINGS.game_mode == .Multiplayer && SETTINGS.multiplayer_mode == .Network {
        clear_socket(SOCK_ACTION)
        clear_socket(SOCK_BOARD)
        write_player_id(0)
    }
    // }}}
}
