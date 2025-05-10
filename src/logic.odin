package elementals

import "core:fmt"
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
            case r < 0.25: {
                type := rand.choice(elements[2*(j/6):][:num_elements])
                level := rand.int_max(3) + 1
                health := rand.int_max(HEALTH_LEVEL[level]) + 1
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

    cell := BOARD.cells[pos.x][pos.y]
    if cell.type != expected_type { return }

    data = cell.data
    if data.type == .Invalid { return }

    aabb = get_cell_aabb(pos, data.level)
    ok = true
    return
}

measure_text :: proc(text: string, text_size: f32 = 64) -> [2]f32 {
    return rl.MeasureTextEx(rl.GetFontDefault(), strings.unsafe_string_to_cstring(text), text_size, 0)
}
