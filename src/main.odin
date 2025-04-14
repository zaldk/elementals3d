package elementals

import "core:fmt"
import "core:strings"
import "core:math"
import "core:math/rand"
import "core:mem"
import "base:intrinsics"
import rl "vendor:raylib"
import tw "tailwind"

Vec3 :: rl.Vector3
Color :: rl.Color
TW :: tw.TW

BLACK :: Color{0,0,0,255}

ENABLED_SHADERS :: #config(SHADERS, false)
TARGET_FPS :: 240
EPSILON :: 0.001
CELL_SIZE :: proc(level := 1) -> Vec3 { return {1, 0.75, 1} * 0.5 * math.pow(f32(level), 0.2) }
CELL_POS :: proc(i,j: int, level := 1) -> Vec3 {
    return {
        f32(i-6)+0.5,
        CELL_SIZE(level).y / 2,
        f32(j-6)+0.5,
    }
}
HEALTH_LEVEL := [?]int{ -1, 1, 2, 6 }
DAMAGE_LEVEL := [?]int{ -1, 1, 2, 4 }

CAMERA : rl.Camera3D
CAM_HEIGHT := 9 * math.sqrt(f32(8) / f32(7))

COLLISION := rl.RayCollision{ distance = math.F32_MAX }
SELECTED_CELL := [2]int{-1, -1}
HOVERING_CELL := [2]int{-1, -1}

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

CellData :: union #no_nil {
    Empty,
    Block,
    Elemental,
}

Cell :: struct {
    data: CellData,
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

ActionType :: enum { Move, Attack, Spell, Skip }
Action :: struct {
    type: ActionType,
}

AnimationType :: enum { Move, Attack, Spell }
ANIMATION := struct {
    active: bool,
}{
    active = false,
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

        ambientLoc := rl.GetShaderLocation(shader, "ambient");
        ambient_light := [4]f32{ 0.1, 0.1, 0.1, 1.0 }
        rl.SetShaderValue(shader, ambientLoc, raw_data(ambient_light[:]), rl.ShaderUniformDataType.VEC4);
    }

    board := new_board()
    // }}}

    // {{{ The Game Loop
    for !rl.WindowShouldClose() {
        // {{{ FRAME RESET
        rl.SetMouseCursor(.DEFAULT)
        // }}}

        // {{{ Collision Calculation
        COLLISION = rl.RayCollision{ distance = math.F32_MAX }
        for i in 0..<12 {
            for j in 0..<12 {
                tile := get_tile_aabb(i,j)
                tile_collision := raytrace(tile.pos - tile.size/2, tile.pos + tile.size/2)

                cell_collision := tile_collision
                if data, ok := board.cells[i][j].data.(Elemental); ok {
                    cell := get_cell_aabb(i, j, data.level)
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
        if COLLISION.hit {
            i, j := point2grid(COLLISION.point)
            HOVERING_CELL = {i,j}
            if _, ok := board.cells[i][j].data.(Elemental); ok {
                rl.SetMouseCursor(.POINTING_HAND)
            }
        }

        // {{{ Input + Animations
        // if CAM_SWITCH {
        //     t := math.unlerp(CAM_TIME, CAM_TIME+CAM_DELTA, f32(rl.GetTime() * 1000))
        //     if t >= 0 && t <= 1 {
        //         angle := math.PI/4 + math.PI * math.smoothstep(f32(0),1,t)
        //         if CAM_POS.x < 0 { angle += math.PI }
        //         CAMERA.position.xz = { f32(math.cos(angle)), f32(math.sin(angle)) } * 6 * math.SQRT_TWO
        //         CAMERA.position.y = CAM_HEIGHT
        //     } else { CAM_SWITCH = false }
        // }
        // if !CAM_SWITCH && rl.IsMouseButtonPressed(.MIDDLE) {
        //     CAM_SWITCH = true
        //     CAM_TIME = f32(rl.GetTime() * 1000)
        //     CAM_POS = CAMERA.position
        // }

        if !rl.IsKeyDown(.LEFT_SHIFT) && rl.GetMouseWheelMoveV().y < 0 { CAMERA.fovy *= 1.1 }
        if !rl.IsKeyDown(.LEFT_SHIFT) && rl.GetMouseWheelMoveV().y > 0 { CAMERA.fovy *= 0.9 }
        if  rl.IsKeyDown(.LEFT_SHIFT) && rl.GetMouseWheelMoveV().y < 0 { rotate_camera(-1) }
        if  rl.IsKeyDown(.LEFT_SHIFT) && rl.GetMouseWheelMoveV().y > 0 { rotate_camera(+1) }
        if rl.GetMouseWheelMoveV().x < 0 { rotate_camera(-1) }
        if rl.GetMouseWheelMoveV().x > 0 { rotate_camera(+1) }

        when ENABLED_SHADERS { rl.SetShaderValue(shader, shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW], raw_data(CAMERA.position[:]), rl.ShaderUniformDataType.VEC3); }

        if !ANIMATION.active && rl.GetKeyPressed() == .Q { board = new_board() }

        if !ANIMATION.active && rl.IsMouseButtonPressed(.LEFT) && COLLISION.hit {
            null_selected := false
            if valid(SELECTED_CELL) && valid(HOVERING_CELL) && !equal(SELECTED_CELL[:], HOVERING_CELL[:]) {
                if _, ok1 := board.cells[HOVERING_CELL.x][HOVERING_CELL.y].data.(Empty); ok1 {
                    if _, ok2 := board.cells[SELECTED_CELL.x][SELECTED_CELL.y].data.(Elemental); ok2 {
                        board.cells[HOVERING_CELL.x][HOVERING_CELL.y] = board.cells[SELECTED_CELL.x][SELECTED_CELL.y]
                        null_selected = true
                    }
                }
            }

            if null_selected {
                board.cells[SELECTED_CELL.x][SELECTED_CELL.y] = Cell{}
            } else if equal(SELECTED_CELL[:], HOVERING_CELL[:]) {
                SELECTED_CELL = {-1,-1}
            } else {
                SELECTED_CELL = HOVERING_CELL
            }
        }
        // }}}

        // {{{ DEBUG INFO
        debug_info : [2]string
        if valid(SELECTED_CELL) { debug_info[0] = fmt.tprintf("Selected: %v %v", SELECTED_CELL, board.cells[SELECTED_CELL.x][SELECTED_CELL.y].data) }
        if valid(HOVERING_CELL) { debug_info[1] = fmt.tprintf("Hovering: %v %v", HOVERING_CELL, board.cells[HOVERING_CELL.x][HOVERING_CELL.y].data) }
        // }}}

        // {{{ Draw Calls
        rl.BeginDrawing(); {
            rl.ClearBackground({0,0,0,255})
            rl.DrawFPS(0,0)

            rl.BeginMode3D(CAMERA); {
                when ENABLED_SHADERS { rl.BeginShaderMode(shader) }

                draw_board(&board)

                when ENABLED_SHADERS { rl.EndShaderMode(); }
            }; rl.EndMode3D()

            for ostr, i in debug_info[:] {
                cstr := strings.clone_to_cstring(ostr)
                defer delete(cstr)
                rl.DrawText(cstr, 20, 20 + 40*i32(i), 20, rl.RAYWHITE)
            }
        }; rl.EndDrawing()
        // }}}
    }
    // }}}
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
            if  tile_blue &&  tile_dark { tile_color = TW(.INDIGO7) }
            if  tile_blue && !tile_dark { tile_color = TW(.INDIGO6) }
            if !tile_blue &&  tile_dark { tile_color = TW(.YELLOW6) }
            if !tile_blue && !tile_dark { tile_color = TW(.YELLOW5) }
            board.tiles[i][j].color = tile_color
            board.tiles[i][j].player = PlayerType(j/6)

            r := rand.float32()
            switch {
            case r < 0.25: {
                type := rand.choice_enum(Element)
                level := rand.choice(levels[:])
                health := int(rand.int31()) % HEALTH_LEVEL[level]
                board.cells[i][j].data = Elemental{ type, level, health }
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
            draw_cube(tile_aabb.pos, tile_aabb.size, tile.color)
        }
    }

    for i in 0..<12 {
        for j in 0..<12 {
            switch data in board.cells[i][j].data {
            case Empty: continue
            case Block: panic("\n\tTODO: implement Block rendering")
            case Elemental: {
                draw_elemental(get_cell_aabb(i, j, data.level), data)
            }
            }
        }
    }
    // }}}
}

get_cell_aabb :: proc(i, j, level: int) -> Box {
    cell_pos := CELL_POS(i, j, level)
    cell_size := CELL_SIZE(level)
    return { cell_pos, cell_size }
}

get_tile_aabb :: proc(i, j: int) -> Box {
    tile_height :: 0.01
    tile_pos := Vec3{f32(i), -tile_height/2, f32(j)} + {-5.5, 0, -5.5}
    tile_size := Vec3{1, tile_height, 1}
    return { tile_pos, tile_size }
}

draw_elemental :: proc(aabb: Box, data: Elemental) {
    // {{{
    BUMP : f32 : 0.05
    draw_cube(aabb.pos, aabb.size, ElementColor[data.type][1])
    draw_cube_wires(aabb.pos, aabb.size, ElementColor[data.type][0])

    for i in 0..<data.level {
        for j in 0..<data.level {
            dot_pos, dot_size : Vec3

            dot_pos.x = (aabb.pos.x - aabb.size.x/2) + aabb.size.x / f32(data.level) * (f32(j) + 0.5)
            dot_pos.y = aabb.pos.y + aabb.size.y/2 + BUMP/2
            dot_pos.z = (aabb.pos.z - aabb.size.z/2) + aabb.size.z / f32(data.level) * (f32(i) + 0.5)

            dot_size = aabb.size * 0.75 / f32(data.level)
            dot_size.y = BUMP

            draw_cube(dot_pos, dot_size, ElementColor[data.type][0])
            draw_cube_wires(dot_pos, dot_size, ElementColor[data.type][1])
        }
    }
    // }}}
}

draw_cube :: proc(pos, size: Vec3, color: Color) { rl.DrawCubeV(pos, size, color) }
draw_cube_wires :: proc(pos, size: Vec3, color: Color) { rl.DrawCubeWiresV(pos, size, color) }

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
    radius : f32 = 6 * math.SQRT_TWO
    CAMERA.position.x /= radius
    CAMERA.position.z /= radius
    alpha := math.atan2(CAMERA.position.z, CAMERA.position.x)
    beta := alpha + f32(direction) * math.PI / 90
    beta -= math.mod(beta, math.PI / 90)
    CAMERA.position.x = math.cos(beta) * radius
    CAMERA.position.z = math.sin(beta) * radius
}
