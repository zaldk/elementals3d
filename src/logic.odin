package elementals

import "core:fmt"
import "core:math"
import "core:slice"
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
    a := action
    cell_A := &game.board.cells[a.pos.x.x][a.pos.x.y]
    cell_B := &game.board.cells[a.pos.y.x][a.pos.y.y]
    switch a.type {
    case .Move:
        data_A, aabb_A := cell_info(a.pos.x, .Elemental) or_return
        data_B, aabb_B := cell_info(a.pos.y, .Empty) or_return

        path, found := get_path(game.board, a.pos)
        if !found { return false }

        cell_B^ = cell_A^
        cell_B.aabb = get_cell_aabb(a.pos.y, data_A.level)
        cell_A^ = Cell{ type = .Empty }
        SELECTED_CELL = a.pos.y
    case .Attack:
        data_A, aabb_A := cell_info(ANIM.pos.x, .Elemental) or_return
        data_B, aabb_B := cell_info(ANIM.pos.y, .Elemental) or_return

        cell_B.data.health = math.clamp(data_B.health - DAMAGE_LEVEL[data_A.level], 0, HEALTH_LEVEL[data_B.level])
        if cell_B.data.health == 0 {
            cell_B.data.level -= 1
            if cell_B.data.level == 0 {
                GAME.board.cells[ANIM.pos.y.x][ANIM.pos.y.y] = Cell{ type = .Empty }
            } else {
                cell_B.data.health = HEALTH_LEVEL[data_B.level]
                cell_B.aabb.size = get_cell_size(data_B.level)
            }
        }
        SELECTED_CELL = {-1,-1}
    case .Spell:
    case .Skip:
    case .Invalid: panic("How?")
    }

    ok = true
    return
}

Direction :: enum byte { I, N, E, S, W }
DirectionDelta := [Direction][2]int{
    .I = {  0,  0 },
    .N = {  0, +1 },
    .E = { +1,  0 },
    .S = {  0, -1 },
    .W = { -1,  0 },
}
get_path :: proc(board: Board, pos: [2][2]int) -> (path: [144]Direction, found: bool) {
    // {{{
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
