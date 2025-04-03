package elementals

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

main :: proc() {
    fmt.println("Hellope")

    rl.SetConfigFlags({ .WINDOW_ALWAYS_RUN, .WINDOW_RESIZABLE, .MSAA_4X_HINT })
    rl.InitWindow(1600, 800, "FLOAT")
    defer rl.CloseWindow()

    camera : rl.Camera3D
    camera.position = { 0, 10, 10 }
    camera.target = { 0, 0, 0 }
    camera.up = { 0, 1, 0 }
    camera.fovy = 45.0
    camera.projection = .PERSPECTIVE

    cubePosition := rl.Vector3{0,0,0}

    for !rl.WindowShouldClose() {

        angle := math.mod(rl.GetTime(), math.TAU * 10) / 10
        camera.position.xz = { f32(math.cos(angle)), f32(math.sin(angle)) } * 10

        rl.BeginDrawing()
        rl.ClearBackground({0x20, 0x20, 0x20, 0xFF})
        {
            rl.BeginMode3D(camera)

            rl.DrawCube(cubePosition, 2, 2, 2, rl.RED);
            rl.DrawCubeWires(cubePosition, 2, 2, 2, rl.RAYWHITE);
            rl.DrawGrid(10, 1);

            rl.EndMode3D()
        }
        rl.EndDrawing()
    }
}
