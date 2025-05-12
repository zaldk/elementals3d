package elementals

import "base:intrinsics"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:strings"
import rl "vendor:raylib"
import tw "tailwind"

draw_board :: proc(board: Board) {
    // {{{
    for i in 0..<12 {
        for j in 0..<12 {
            tile := board.tiles[i][j]
            tile_aabb := get_tile_aabb(i,j)
            draw_cube(tile_aabb, tile.color)
            // tile_aabb_wires := Box{ tile_aabb.pos, tile_aabb.size * {0.99, 1, 0.99} }
            // draw_cube_wires(tile_aabb_wires, get_tile_color((i+1)%12,j))
        }
    }

    for i in 0..<12 {
        for j in 0..<12 {
            switch board.cells[i][j].type {
            case .Empty: continue
            case .Block: panic("\n\tTODO: implement Block rendering")
            case .Elemental: draw_elemental(board.cells[i][j].aabb, board.cells[i][j].data)
            case .None: panic("How?")
            }
        }
    }
    // }}}
}

draw_elemental :: proc(aabb: Box, data: Elemental) {
    // {{{
    BUMP : f32 : 0.05
    draw_cube(aabb, ElementColor[data.type][1])

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

draw_all_elemental_wires :: proc(board: Board) {
    // {{{
    for i in 0..<12 {
        for j in 0..<12 {
            if board.cells[i][j].type != .Elemental { continue }
            draw_elemental_wires(board.cells[i][j].aabb, board.cells[i][j].data)
        }
    }
    // }}}
}

draw_all_healths :: proc(board: Board) {
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

    switch data.level {
    case 1, 2, 3: for i in 0..<hp_max {
        hp : Box
        hp.size = { hp_width, hp_width, hp_depth }
        hp.pos.x = aabb.pos.x + (-aabb.size.x/2 + hp_gap + hp_width/2 + f32(i)*(hp_gap + hp_width)) * (_reverse ? -1 : 1)
        hp.pos.y = aabb.pos.y
        hp.pos.z = aabb.pos.z + aabb.size.z/2 * (_reverse ? -1 : 1)

        empty := i >= data.health
        damaged := i >= data.health-damage

        draw_cube(hp, empty ? TW(.SLATE5) : damaged ? TW(.RED5) : TW(.YELLOW4))
        // draw_cube_wires(hp, BLACK)
    }
    }

    if _reverse { draw_health(aabb, data, damage, false) }
    // }}}
}

highlight_cell :: proc(board: Board, pos: [2]int) {
    // color := get_tile_color(pos.x, pos.y)
    color := Color{255,255,255, 51}
    aabb := get_tile_aabb(pos.x, pos.y)
    aabb.size.y *= 1.1
    draw_cube(aabb, color)
}

draw_path :: proc(pos: [2]int, path: []Direction) {
    sum := pos
    for i in 0..<get_path_length(path) {
        draw_arrow(sum, path[i])
        sum += DirectionDelta[path[i]]
    }
}

draw_arrow :: proc(pos: [2]int, dir: Direction) {
    di := DirectionDelta[dir]
    d := [2]f32{f32(di.x), f32(di.y)}
    // 0.75 rod + 0.25 tip
    rod := get_tile_aabb(pos.x, pos.y)
    rod.pos.x += d.x * (0.5 - 0.125)
    rod.pos.z += d.y * (0.5 - 0.125)
    rod.size.x = math.abs(d.x) * (0.25 + 0.125)
    rod.size.z = math.abs(d.y) * (0.25 + 0.125)
    rod.pos.y = 0.015
    rod.size.x = math.max(rod.size.x, 0.1)
    rod.size.y = 0.01
    rod.size.z = math.max(rod.size.z, 0.1)
    draw_cube(rod, {255,255,255,153})

    tip : [3]Vec3
    tip.x = get_tile_aabb(pos.x, pos.y).pos
    tip.y = tip.x
    tip.z = tip.x
    tip.x.y = 0.015; tip.y.y = 0.015; tip.z.y = 0.015

    tip.x.x += d.x * 0.5 + (d.y != 0 ? 0.125 : 0)
    tip.x.z += d.y * 0.5 + (d.x != 0 ? 0.125 : 0)

    tip.y.x += d.x * 0.75
    tip.y.z += d.y * 0.75

    tip.z.x += d.x * 0.5 - (d.y != 0 ? 0.125 : 0)
    tip.z.z += d.y * 0.5 - (d.x != 0 ? 0.125 : 0)

    rl.DrawTriangle3D(tip.x, tip.y, tip.z, {255,255,255,153})
    rl.DrawTriangle3D(tip.z, tip.y, tip.x, {255,255,255,153})
}

draw_cube :: proc { draw_cube_Vec3, draw_cube_Box }
draw_cube_Vec3 :: proc(pos, size: Vec3, color: Color) { rl.DrawCubeV(pos, size, color) }
draw_cube_Box :: proc(aabb: Box, color: Color) { rl.DrawCubeV(aabb.pos, aabb.size, color) }

draw_cube_wires :: proc { draw_cube_wires_Vec3, draw_cube_wires_Box }
draw_cube_wires_Vec3 :: proc(pos, size: Vec3, color: Color) { rl.DrawCubeWiresV(pos, size, color) }
draw_cube_wires_Box :: proc(aabb: Box, color: Color) { rl.DrawCubeWiresV(aabb.pos, aabb.size, color) }

get_tile_color :: proc(i, j: int) -> Color {
    // {{{
    tile_color : Color = {0, 0, 0, 255}
    tile_blue := j < 6
    tile_dark := (i+j) % 2 == 0
    if  tile_blue &&  tile_dark { tile_color = TW(.BLUE5)  } // TW(.INDIGO7) }
    if  tile_blue && !tile_dark { tile_color = TW(.BLUE4)  } // TW(.INDIGO6) }
    if !tile_blue &&  tile_dark { tile_color = TW(.GREEN5) } // TW(.YELLOW6) }
    if !tile_blue && !tile_dark { tile_color = TW(.GREEN4) } // TW(.YELLOW5) }
    tile_color.rgb = tile_color.rgb/16 * 10
    return tile_color
    // }}}
}

get_cell_size :: proc(level := 1) -> Vec3 {
    return {1, 0.75, 1} * 0.5 * math.pow(f32(level), 0.2)
}
get_cell_pos :: proc(i,j: int, level := 1) -> Vec3 {
    return { f32(i), get_cell_size(level).y / 2, f32(j) } - {5.5,0,5.5}
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
        fmt.printfln("File %v Line %v: Box outside the board %v", #file, #line, box)
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

get_cell_aabb :: proc { get_cell_aabb_ij, get_cell_aabb_2int }
get_cell_aabb_ij :: proc(i, j, level: int) -> Box {
    if level == 0 { return Box{} }
    cell_pos := get_cell_pos(i, j, level)
    cell_size := get_cell_size(level)
    return { cell_pos, cell_size }
}
get_cell_aabb_2int :: proc(pos: [2]int, level: int) -> Box {
    if level == 0 { return Box{} }
    cell_pos := get_cell_pos(pos.x, pos.y, level)
    cell_size := get_cell_size(level)
    return { cell_pos, cell_size }
}

get_tile_aabb :: proc(i, j: int) -> Box {
    tile_height :: 0.1
    tile_size := Vec3{1, tile_height, 1}
    tile_pos := Vec3{f32(i) - 5.5, -tile_size.y/2, f32(j) - 5.5}
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
    return grid_pos.x >= 0 && grid_pos.x <= 11 &&
           grid_pos.y >= 0 && grid_pos.y <= 11
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

get_cell :: proc(board: Board, pos: [2]int) -> Cell {
    return board.cells[pos.x][pos.y]
}

get_time :: proc() -> f32 {
    return f32(rl.GetTime()) * 1000
}

measure_text :: proc(text: string, text_size: f32 = 64) -> [2]f32 {
    return rl.MeasureTextEx(rl.GetFontDefault(), strings.unsafe_string_to_cstring(text), text_size, 0)
}

// ================================================================================

_IS_HOVERING_OVER_BUTTONS := false
// state: 0=normal 1=hover 2=press
button :: proc(aabb: [4]f32) -> (state: int, action: bool) {
    if rl.CheckCollisionPointRec(rl.GetMousePosition(), rl.Rectangle{ aabb.x, aabb.y, aabb.z, aabb.w }) {
        _IS_HOVERING_OVER_BUTTONS = true
        state = 1 + int(rl.IsMouseButtonDown(.LEFT))
        action = rl.IsMouseButtonPressed(.LEFT)
    } else { state = 0 }
    return
}
