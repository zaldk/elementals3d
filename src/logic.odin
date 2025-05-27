package elementals

import "core:os"
import "core:encoding/json"
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
                level := 1 //rand.int_max(3) + 1
                health := HEALTH_LEVEL[level] //rand.int_max(HEALTH_LEVEL[level]) + 1
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
merge_board :: proc(board: ^Board, player: PlayerType) -> int {
    // {{{
    new_charges := 0
    next := board^
    todo := [12][6]byte{} // 0=nop << 1=remove << 2=ascend ; low_priority << high_priority
    o := (int(player)-1) * 12 / 2

    for row in 1..<11 {
        for col in 1..<5 {
            for i := 0; i < len(merge_configurations); i += 1 {
                conf := merge_configurations[i]
                a := board.cells[row+conf[0][1]][col+conf[0][0]+o]
                b := board.cells[row+conf[1][1]][col+conf[1][0]+o]
                c := board.cells[row+conf[2][1]][col+conf[2][0]+o]
                if !(a.type == .Elemental && b.type == .Elemental && c.type == .Elemental &&
                     a.data.type  == b.data.type  && b.data.type  == c.data.type  &&
                     a.data.level == b.data.level && b.data.level == c.data.level &&
                    (a.data.level == 1 || a.data.level == 2)) {
                    continue
                }
                todo[row+conf[0][1]][col+conf[0][0]] |= 0b01
                todo[row+conf[1][1]][col+conf[1][0]] |= 0b10
                todo[row+conf[2][1]][col+conf[2][0]] |= 0b01
            }
        }
    }

    for row in 0..<12 {
        for col in 0..<6 {
            switch todo[row][col] {
            case 0b00: break
            case 0b01: next.cells[row][col+o] = { type = .Empty }
            case 0b10: fallthrough
            case 0b11:
                new_charges += next.cells[row][col+o].data.level
                next.cells[row][col+o].data.level += 1
                next.cells[row][col+o].aabb.size  = get_cell_size(next.cells[row][col+o].data.level)
                next.cells[row][col+o].data.health = HEALTH_LEVEL[next.cells[row][col+o].data.level]
            }
        }
    }

    board^ = next
    return new_charges
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
        ok = true
    case .Attack:
        cell_A := &game.board.cells[a.pos.x.x][a.pos.x.y]
        cell_B := &game.board.cells[a.pos.y.x][a.pos.y.y]

        data_A, aabb_A := cell_info(a.pos.x, .Elemental) or_return
        data_B, aabb_B := cell_info(a.pos.y, .Elemental) or_return

        is_attackable(a.pos.x, a.pos.y) or_return

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
        game.used_attack = true
        SELECTED_CELL = -1
        start_animation(.Skip)
        ok = true
    case .Spell:
        game.used_spell = true
        start_animation(.Skip)
        ok = true
    case .Skip:
        merge_board(&GAME.board, PlayerType(1+(GAME.turn&1)))
        SELECTED_CELL = -1
        game.turn += 1
        game.used_spell  = false
        game.used_move   = false
        game.used_attack = false
        ok = true
    case .None:
        panic("How?")
    }

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
        if !game.used_move {
            for i in 0..<12 {
                for j in 0..<12 {
                    if game.board.cells[i][j].type == .Elemental {
                        if game.turn&1 == j/6 {
                            append(&elem_self,  [2]int{i, j})
                        } else {
                            append(&elem_enemy, [2]int{i, j})
                        }
                    }
                }
            }
        } else {
            if valid(SELECTED_CELL) {
                append(&elem_self, SELECTED_CELL)
            }
            for i in 0..<12 {
                for j in 0..<12 {
                    if game.board.cells[i][j].type == .Elemental && game.turn&1 != j/6 {
                        append(&elem_enemy, [2]int{i, j})
                    }
                }
            }
        }
        if len(elem_self) == 0 || len(elem_enemy) == 0 { break }
        rand.shuffle(elem_self[:])
        rand.shuffle(elem_enemy[:])
        for s in elem_self {
            for e in elem_enemy {
                if !is_attackable(s, e) { continue }
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

start_animation :: proc(type: AnimationType, pos: [2][2]int = {}, spell: Spell = .None) {
    duration : f32
    switch type {
    case .None:   return
    case .Move:   duration = 500 + 100 * f32(get_path_length(MOVE_PATH[:]))
    case .Attack: duration = 1000; rl.PlaySound(ATTACK_SOUND)
    case .Spell:  duration = 100
    case .Skip:   duration = 500
    }
    ANIM = {
        active = true,
        type = type,
        start = get_time(),
        duration = duration,
        pos = pos,
        spell = spell,
    }
}

can_attack :: proc(board: Board, p: [2]int) -> bool {
    if valid(p) && get_cell(board, p).type == .Elemental {
        reach := REACH_LEVEL[get_cell(board, p).data.level]
        for i in math.max(p.x-1, 0)..<math.min(p.x+2, 12) {
            for j in 0..<12 {
                if j/6 == p.y/6 { continue }
                if math.abs(j - p.y) > reach { continue }
                if board.cells[i][j].type != .Elemental { continue }
                return true
            }
        }
    }
    return false
}

execute_ai :: proc() {
    // {{{
    if ANIM.active { return }

    act_types : [dynamic]ActionType; defer delete(act_types)
    used := [?]bool{GAME.used_spell, GAME.used_move, GAME.used_attack}
    b := [?]bool{false, true}
    if used == b.xxx { append(&act_types, ActionType.Attack, ActionType.Move) }//, ActionType.Spell) }
    if used == b.yxx { append(&act_types, ActionType.Attack, ActionType.Move) }
    if used == b.xyx { append(&act_types, ActionType.Attack) }
    if used == b.yyx { append(&act_types, ActionType.Attack) }

    act_type := len(act_types) == 0 ? ActionType.Skip : rand.choice(act_types[:])
    act, ok_gen := get_random_action(GAME, act_type)
    if !ok_gen { act = Action{ type = .Skip } }
    // fmt.println(ok_gen, act)

    switch act.type {
    case .Move:
        path, found := get_path(GAME.board, act.pos)
        if found {
            MOVE_PATH = path
            SELECTED_CELL = act.pos.x
            HOVERING_CELL = act.pos.y
            UPDATE_HOVER = false
            RESET_SELECTED = false
            start_animation(.Move, act.pos)
        }
    case .Attack:
        SELECTED_CELL = act.pos.x
        HOVERING_CELL = act.pos.y
        start_animation(.Attack, act.pos)
    case .Spell: fallthrough
    case .Skip: start_animation(.Skip)
    case .None: panic("How?")
    }
    // }}}
}

is_attackable :: proc(from, to: [2]int) -> bool {
    if math.abs(from.x - to.x) > 1 { return false } // outside X range
    from_level := GAME.board.cells[from.x][from.y].data.level
    if from_level == 0 { return false }
    if math.abs(from.y - to.y) > REACH_LEVEL[from_level] { return false } // outside Y range
    return true
}

SOCK_ACTION    :: ".net/action"
SOCK_PLAYER_ID :: ".net/player_id"
SOCK_BOARD     :: ".net/board"

is_socket_empty :: proc(path: string) -> bool {
    return os.file_size_from_path(path) <= 0
}

clear_socket :: proc(path: string) -> bool {
    werr := os.write_entire_file_or_err(path, {})
    if werr != nil {
        fmt.eprintfln("Unable to write file: %v", werr)
        return false
    }
    return true
}

read_action :: proc() -> (Action, bool) {
    data, ok := os.read_entire_file_from_filename(SOCK_ACTION)
    if !ok {
        fmt.eprintln("Failed to load the file!")
        return {}, false
    }
    defer delete(data) // Free the memory at the end

    // fmt.printfln("%#v", data[0])
    // if GAME_PLAYER_ID == int('0' - data[0]) {
    //     return {}, false
    // }

    // Load data from the json bytes directly to the struct
    action: Action
    unmarshal_err := json.unmarshal(data, &action)
    if unmarshal_err != nil {
        fmt.eprintln("Failed to unmarshal the file!")
        return {}, false
    }

    return action, true
}

write_action :: proc(action: Action) -> bool {
    json_data, err := json.marshal(action)
    if err != nil {
        fmt.eprintfln("Unable to marshal JSON: %v", err)
        return false
    }
    defer delete(json_data)

    // pid := [?]byte{byte(GAME_PLAYER_ID)}
    // data_all := [?][]byte{pid[:], json_data}
    // data, ok := slice.concatenate(data_all[:])
    // defer delete(data)

    werr := os.write_entire_file_or_err(SOCK_ACTION, json_data)
    if werr != nil {
        fmt.eprintfln("Unable to write file: %v", werr)
        return false
    }

    return true
}

read_player_id :: proc() -> int {
    data, ok := os.read_entire_file_from_filename(SOCK_PLAYER_ID)
    if !ok {
        fmt.eprintln("Failed to load the file!")
        write_player_id(1)
        return 0
    }
    defer delete(data)

    content := string(data)
    if content == "0" {
        write_player_id(1)
        return 0
    } else {
        write_player_id(0)
        return 1
    }
}

write_player_id :: proc(pid: int) -> bool {
    werr := os.write_entire_file_or_err(SOCK_PLAYER_ID, {'0'+u8(pid)})
    if werr != nil {
        fmt.eprintfln("Unable to write file: %v", werr)
        return false
    }
    return true
}

read_board :: proc() -> (Board, bool) {
    data, ok := os.read_entire_file_from_filename(SOCK_BOARD)
    if !ok {
        fmt.eprintln("Failed to load the file!")
        return {}, false
    }
    defer delete(data) // Free the memory at the end

    // Load data from the json bytes directly to the struct
    board: Board
    unmarshal_err := json.unmarshal(data, &board)
    if unmarshal_err != nil {
        fmt.eprintln("Failed to unmarshal the file!")
        return {}, false
    }

    return board, true
}

write_board :: proc(board: Board) -> bool {
    json_data, err := json.marshal(board)
    if err != nil {
        fmt.eprintfln("Unable to marshal JSON: %v", err)
        return false
    }
    defer delete(json_data)

    werr := os.write_entire_file_or_err(SOCK_BOARD, json_data)
    if werr != nil {
        fmt.eprintfln("Unable to write file: %v", werr)
        return false
    }

    return true
}
