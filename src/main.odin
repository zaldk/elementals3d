package elementals

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

main :: proc() {
    fmt.println("Hellope")

    rl.SetConfigFlags({ .WINDOW_ALWAYS_RUN, .WINDOW_RESIZABLE, .MSAA_4X_HINT })
    rl.InitWindow(1600, 1000, "FLOAT")
    defer rl.CloseWindow()

    camera : rl.Camera3D
    camera.position = { 6, 8, 6 }
    camera.target = { 0, 0, 0 }
    camera.up = { 0, 1, 0 }
    camera.fovy = 15
    camera.projection = .ORTHOGRAPHIC

    cubePosition := rl.Vector3{ 0.5, 0.5, 0.5 }
    cubeSize := rl.Vector3{1,1,1}

    for !rl.WindowShouldClose() {

        angle := math.mod(rl.GetTime(), math.TAU * 10) / 10
        // camera.position = { f32(math.cos(angle)), 1, f32(math.sin(angle)) } * 4

        rl.BeginDrawing()
        rl.ClearBackground({0x20, 0x20, 0x20, 0xFF})
        {
            rl.BeginMode3D(camera)
            rl.DrawGrid(12, 1);

            rl.DrawCubeV(cubePosition, cubeSize, {255, 0, 0, 127});
            rl.DrawCubeWiresV(cubePosition, cubeSize, rl.RAYWHITE);

            draw_board_plane()

            rl.EndMode3D()
        }
        rl.EndDrawing()
    }
}

draw_board_plane :: proc() {
    cell_height :: 0.01
    for i in -6..<6 {
        for j in -6..<6 {
            col : rl.Color = {0, 0, 0, 255}
            if j < 0 { col.g = 255 } else { col.b = 255 }
            rl.DrawCubeV({f32(i), -cell_height/2, f32(j)} + {0.5,0,0.5}, {1, cell_height, 1}, col)
        }
    }
}
