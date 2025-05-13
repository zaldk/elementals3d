package elementals

import "core:fmt"
import "core:slice"
import "core:math"
import "core:math/rand"
import "core:strings"
import rl "vendor:raylib"

new_board :: proc() -> (board: Board) {
    // {{{
    levels := [?]int{-1, 1, 2, 3}
    num_elements := rand.int_max(2) + 1
    all_elements := [?]Element{ .Air, .Fire, .Rock, .Water, .Nature, .Energy }
    rand.shuffle(all_elements[:])
    elements := all_elements[:4]
    for i in 0..<12 {
        for j in 0..<12 {
            board.tiles[i][j].color = get_tile_color(i,j)
            board.tiles[i][j].player = PlayerType(j/6)

            r := rand.float32()
            switch {
            case r < 0.25:
                type := rand.choice(elements[2*(j/6):][:num_elements])
                level := rand.int_max(3) + 1
                health := rand.int_max(HEALTH_LEVEL[level]) + 1
                board.cells[i][j].data = Elemental{ type, level, health }
                board.cells[i][j].type = .Elemental
                board.cells[i][j].aabb = get_cell_aabb(i, j, level)
            // case r < 0.5: board.cells[i][j] = Block{}
            case: board.cells[i][j].type = .Empty
            }
        }
    }

    return
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

cell_info :: proc(pos: [2]int, expected_type: CellType) -> (data: Elemental, aabb: Box, ok: bool) {
    if !valid(pos) { return }

    cell := GAME.board.cells[pos.x][pos.y]
    if cell.type != expected_type { return }

    data = cell.data
    aabb = get_cell_aabb(pos, data.level)
    ok = true
    return
}

apply_action :: proc(game: ^Game, action: Action) -> (ok: bool) {
    // {{{
    a := action
    switch a.type {
    case .Move:
        cell_A := &game.board.cells[a.pos.x.x][a.pos.x.y]
        cell_B := &game.board.cells[a.pos.y.x][a.pos.y.y]

        data_A, aabb_A := cell_info(a.pos.x, .Elemental) or_return
        data_B, aabb_B := cell_info(a.pos.y, .Empty) or_return

        path, found := get_path(game.board, a.pos)
        if !found { return false }

        cell_B^ = cell_A^
        cell_B.aabb = get_cell_aabb(a.pos.y, data_A.level)
        cell_A^ = Cell{ type = .Empty }
        SELECTED_CELL = a.pos.y
        game.used_move = true
    case .Attack:
        cell_A := &game.board.cells[a.pos.x.x][a.pos.x.y]
        cell_B := &game.board.cells[a.pos.y.x][a.pos.y.y]

        data_A, aabb_A := cell_info(a.pos.x, .Elemental) or_return
        data_B, aabb_B := cell_info(a.pos.y, .Elemental) or_return

        cell_B.data.health = math.clamp(data_B.health - DAMAGE_LEVEL[data_A.level], 0, HEALTH_LEVEL[data_B.level])
        if cell_B.data.health == 0 {
            cell_B.data.level -= 1
            if cell_B.data.level == 0 {
                GAME.board.cells[a.pos.y.x][a.pos.y.y] = Cell{ type = .Empty }
            } else {
                cell_B.data.health = HEALTH_LEVEL[cell_B.data.level]
                cell_B.aabb.size = get_cell_size(cell_B.data.level)
            }
        }
        SELECTED_CELL = {-1,-1}
        start_animation(.Skip, 300)
    case .Spell:
        game.used_spell  = true
        start_animation(.Skip, 300)
    case .Skip:
        game.turn += 1
        game.used_spell  = false
        game.used_move   = false
        game.used_attack = false
    case .None:
        panic("How?")
    }

    ok = true
    return
    // }}}
}

Direction :: enum byte { I, N, E, S, W }
DirectionDelta := [Direction][2]int{
    .N = {  0, +1 },
    .E = { +1,  0 },
    .S = {  0, -1 },
    .W = { -1,  0 },
    .I = {  0,  0 },
}
get_path :: proc(board: Board, pos: [2][2]int) -> (path: [144]Direction, found: bool) {
    // {{{
    player := get_player(pos.x)
    if player != get_player(pos.y) { return }
    FREE    :: 1 << 0
    BLOCKED :: 1 << 1
    VISITED :: 1 << 2
    GOAL    :: 1 << 3
    PATH    :: 1 << 4
    grid: [12][12]byte
    for x in 0..<12 {
        for y in 0..<12 {
            grid[x][y] = FREE
            if board.cells[x][y].type != .Empty {
                grid[x][y] = BLOCKED
            }
            if x == pos.x.x && y == pos.x.y {
                grid[x][y] = VISITED
            }
            if x == pos.y.x && y == pos.y.y {
                grid[x][y] = GOAL
            }
        }
    }

    bfs :: proc(grid: ^[12][12]byte, start: [2]int, goal: [2]int, path: []Direction) -> (found: bool) {
        DIRS :: [4]Direction{.N,.E,.S,.W}
        queue := make([dynamic][2]int)
        defer delete(queue)
        parent : [12][12][2]int = -1
        direction : [12][12][dynamic]Direction
        defer for i in 0..<12*12 { delete(direction[i/12][i%12]) }

        grid[start.x][start.y] |= VISITED
        append(&queue, start)

        for len(queue) > 0 {
            curr := pop_front(&queue)
            if curr == goal {
                curr_pos := goal
                for curr_pos != start {
                    par_pos := parent[curr_pos.x][curr_pos.y]
                    if len(direction[curr_pos.x][curr_pos.y]) > 0 {
                        path_index := get_path_length(path[:])
                        if path_index != -1 { path[path_index] = direction[curr_pos.x][curr_pos.y][0] }
                    }
                    curr_pos = par_pos
                }
                return true
            }
            for d in DIRS {
                next := curr + DirectionDelta[d]
                if !valid(next) { continue }
                if (grid[next.x][next.y] & (BLOCKED | VISITED)) != 0 { continue }
                if get_player(start) != get_player(next) { continue }

                grid[next.x][next.y] |= VISITED
                parent[next.x][next.y] = curr
                append(&direction[next.x][next.y], d)
                append(&queue, next)
            }
        }
        return false
    }

    found = bfs(&grid, pos.x, pos.y, path[:])
    slice.reverse(path[:get_path_length(path[:])])
    return
    // }}}
}
get_path_length :: proc(path: []Direction) -> int {
    for i in 0..<len(path) {
        if path[i] == .I {
            return i
        }
    }
    return -1
}
get_path_pos :: proc(path: []Direction, start, end: Vec3, t:f32=0) -> Vec3 {
    // {{{
    total_length := f32(get_path_length(path))
    prev_pos := start
    curr_pos := start

    running_length := f32(0)
    for i in 0..<get_path_length(path)+1 {
        if f32(i) / total_length >= t {
            v := math.mod(t, 1.0 / total_length)
            v *= total_length
            return math.lerp(prev_pos, curr_pos, v)
        }

        dir := DirectionDelta[path[i]]
        d := Vec3{f32(dir.x), 0, f32(dir.y)}
        prev_pos = curr_pos
        curr_pos = prev_pos + d
    }

    return curr_pos
    // }}}
}

get_player :: proc(pos: [2]int) -> PlayerType {
    return PlayerType(1 + pos.y/6)
}

get_random_action :: proc(game: Game, type: ActionType) -> (act: Action, ok: bool) {
    // {{{
    // player:    0|blue     1|green
    // cell.y/j: <6|blue   >=6|green
    switch type {
    case .Attack:
        elem_self, elem_enemy : [dynamic][2]int
        defer delete(elem_self); defer delete(elem_enemy)
        for i in 0..<12 {
            for j in 0..<12 {
                if game.board.cells[i][j].type == .Elemental {
                    append(j/6 == (game.turn&1) ? &elem_self : &elem_enemy,  [2]int{i, j})
                }
            }
        }
        if len(elem_self) == 0 || len(elem_enemy) == 0 { break }
        rand.shuffle(elem_self[:])
        rand.shuffle(elem_enemy[:])
        for s in elem_self {
            for e in elem_enemy {
                if math.abs(s.x - e.x) > 1 { continue } // outside X range
                s_level := game.board.cells[s.x][s.y].data.level
                if math.abs(s.y - e.y) > REACH_LEVEL[s_level] { continue } // outside Y range
                act.type = .Attack
                act.pos = { s, e }
                return act, true
            }
        }
        return {}, false
    case .Move:
        delta := 6 * (game.turn&1)
        elementals, empty_cells : [dynamic][2]int
        defer delete(elementals); defer delete(empty_cells)
        for i in 0..<12 {
            for j in delta..<6+delta {
                if game.board.cells[i][j].type == .Elemental { append(&elementals,  [2]int{i, j}) }
                if game.board.cells[i][j].type == .Empty     { append(&empty_cells, [2]int{i, j}) }
            }
        }
        if len(elementals) == 0 || len(empty_cells) == 0 { break }
        rand.shuffle(elementals[:])
        rand.shuffle(empty_cells[:])
        for elem_pos in elementals {
            for empty_pos in empty_cells {
                path, found := get_path(game.board, { elem_pos, empty_pos })
                if !found { continue }
                act.type = .Move
                act.pos = { elem_pos, empty_pos }
                return act, true
            }
        }
        return {}, false
    case .Spell: fallthrough
    case .Skip: return Action{ type = .Skip }, true
    case .None: return {}, false
    }
    return {}, false
    // }}}
}

get_elementals_in_attack_range :: proc(board: Board) -> [dynamic][2]int {
    return {}
}

start_animation :: proc(type: AnimationType, duration: f32, pos: [2][2]int = {}, spell: Spell = .None) {
    ANIM = {
        active = true,
        type = type,
        start = get_time(),
        duration = duration,
        pos = pos,
        spell = spell,
    }
}

execute_ai :: proc() {
    // {{{
    if ANIM.active { return }

    act_types : [dynamic]ActionType; defer delete(act_types)
    used := [?]bool{GAME.used_spell, GAME.used_move, GAME.used_attack}
    b := [?]bool{false, true}
    if used == b.xxx { append(&act_types, ActionType.Attack, ActionType.Move, ActionType.Spell) }
    if used == b.xyx { append(&act_types, ActionType.Attack) }
    if used == b.yxx { append(&act_types, ActionType.Attack, ActionType.Move) }
    if used == b.yyx { append(&act_types, ActionType.Attack) }

    act_type := len(act_types) == 0 ? ActionType.Skip : rand.choice(act_types[:])
    act, ok_gen := get_random_action(GAME, act_type)
    if !ok_gen { act = Action{ type = .Skip } }
    fmt.println(ok_gen, act)

    switch act.type {
    case .Move:
        path, found := get_path(GAME.board, act.pos)
        if found {
            start_animation(.Move, 500 + 100 * f32(get_path_length(path[:])), act.pos)
            MOVE_PATH = path
            SELECTED_CELL = act.pos.x
            HOVERING_CELL = act.pos.y
            UPDATE_HOVER = false
        }
    case .Attack: start_animation(.Attack, 1000, act.pos)
    case .Spell: fallthrough
    case .Skip: start_animation(.Skip, 300)
    case .None: panic("How?")
    }
    // }}}
}
