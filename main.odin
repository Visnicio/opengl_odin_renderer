package main

import "core:math"
import "core:fmt"
import "core:os"
import "core:strings"
import "base:runtime"
import "core:math/linalg"

import "engine"

import "vendor:glfw"
import gl "vendor:OpenGL"
import stb_image "vendor:stb/image"

import imgui "odin-imgui"
import imgui_gl "odin-imgui/imgui_impl_opengl3"
import imgui_glfw "odin-imgui/imgui_impl_glfw"


EngineState :: struct {
    window: glfw.WindowHandle,
    main_camera: ^engine.Camera
}

engine_state: EngineState

CubeTest :: struct {
    // quads: [6]^Quad,
    mesh: ^engine.Mesh,
    position: engine.Vec3,
    rotation: engine.Vec3
}

lastMouseX : f64 = 400
lastMouseY : f64 = 300
mouse_captured: bool = true

cube_test_create :: proc(position: engine.Vec3) -> ^CubeTest {
    // 8 cantos do cubo:
    //
    //        p011 ───────────── p111
    //        /│                 /│
    //       / │                / │
    //     p010 ──────────── p110 │
    //      │   │             │   │
    //      │  p001 ──────────┼─ p101
    //      │  /              │  /
    //      │ /               │ /
    //     p000 ───────────── p100
    //
    // Cada face tem 4 vértices PRÓPRIOS (24 no total), então cada uma
    // recebe UVs independentes {0,0}..{1,1} sem conflito com as vizinhas.
    // UV por canto da face: 0=(0,0) bottom-left, 1=(1,0) bottom-right,
    //                       2=(1,1) top-right,    3=(0,1) top-left

    cube_vertices: []engine.VertexData = {
        // FRONT (+z)
        { position = {-0.5, -0.5,  0.5}, color = {1,1,1}, uv = {0, 0} },
        { position = { 0.5, -0.5,  0.5}, color = {1,1,1}, uv = {1, 0} },
        { position = { 0.5,  0.5,  0.5}, color = {1,1,1}, uv = {1, 1} },
        { position = {-0.5,  0.5,  0.5}, color = {1,1,1}, uv = {0, 1} },

        // BACK (-z)
        { position = { 0.5, -0.5, -0.5}, color = {1,1,1}, uv = {0, 0} },
        { position = {-0.5, -0.5, -0.5}, color = {1,1,1}, uv = {1, 0} },
        { position = {-0.5,  0.5, -0.5}, color = {1,1,1}, uv = {1, 1} },
        { position = { 0.5,  0.5, -0.5}, color = {1,1,1}, uv = {0, 1} },

        // LEFT (-x)
        { position = {-0.5, -0.5, -0.5}, color = {1,1,1}, uv = {0, 0} },
        { position = {-0.5, -0.5,  0.5}, color = {1,1,1}, uv = {1, 0} },
        { position = {-0.5,  0.5,  0.5}, color = {1,1,1}, uv = {1, 1} },
        { position = {-0.5,  0.5, -0.5}, color = {1,1,1}, uv = {0, 1} },

        // RIGHT (+x)
        { position = { 0.5, -0.5,  0.5}, color = {1,1,1}, uv = {0, 0} },
        { position = { 0.5, -0.5, -0.5}, color = {1,1,1}, uv = {1, 0} },
        { position = { 0.5,  0.5, -0.5}, color = {1,1,1}, uv = {1, 1} },
        { position = { 0.5,  0.5,  0.5}, color = {1,1,1}, uv = {0, 1} },

        // TOP (+y)
        { position = {-0.5,  0.5,  0.5}, color = {1,1,1}, uv = {0, 0} },
        { position = { 0.5,  0.5,  0.5}, color = {1,1,1}, uv = {1, 0} },
        { position = { 0.5,  0.5, -0.5}, color = {1,1,1}, uv = {1, 1} },
        { position = {-0.5,  0.5, -0.5}, color = {1,1,1}, uv = {0, 1} },

        // BOTTOM (-y)
        { position = {-0.5, -0.5, -0.5}, color = {1,1,1}, uv = {0, 0} },
        { position = { 0.5, -0.5, -0.5}, color = {1,1,1}, uv = {1, 0} },
        { position = { 0.5, -0.5,  0.5}, color = {1,1,1}, uv = {1, 1} },
        { position = {-0.5, -0.5,  0.5}, color = {1,1,1}, uv = {0, 1} },
    }

    // Cada face: 4f+0, 4f+1, 4f+2  /  4f+0, 4f+2, 4f+3  (winding CCW)
    cube_indices: []u32 = {
         0,  1,  2,   0,  2,  3, // front
         4,  5,  6,   4,  6,  7, // back
         8,  9, 10,   8, 10, 11, // left
        12, 13, 14,  12, 14, 15, // right
        16, 17, 18,  16, 18, 19, // top
        20, 21, 22,  20, 22, 23, // bottom
    }

    new_cube: ^CubeTest = new(CubeTest)
    new_cube.position = position
    new_cube.rotation = engine.Vec3{0, 0, 0}
    new_cube.mesh = engine.mesh_create(cube_vertices, cube_indices)
    return new_cube
}

// calls this as defer soon after creating the cube if needed, frees the cube, and quads, and handles quad freeing
cube_test_destroy :: proc(c: ^CubeTest) {
    engine.mesh_destroy(c.mesh)
    free(c)
}

cube_test_update :: proc(cube: ^CubeTest) {
    // for q in cube.quads {
    //     if q != nil {
    //         // new_cube.quads[2].position = position - Vec3{-0.5, 0, 00} // right face
    //         q.position *= cube.position
    //     }
    // }
    // cube.quads[0].position = cube.position - Vec3{0, 0, -0.5} // front face
    // cube.quads[1].position = cube.position - Vec3{0, 0, 0.5} // back face
    // cube.quads[2].position = cube.position - Vec3{-0.5, 0, 00} // right face
    // cube.quads[3].position = cube.position - Vec3{0.5, 0, 00} // left face
    // cube.quads[4].position = cube.position - Vec3{0.0, -0.5, 00} // top face
    // cube.quads[5].position = cube.position - Vec3{0.0, 0.5, 00} // bottom face
    // for &vertex_data in cube.mesh.vertices {
    //     vertex_data.position = vertex_data.position * cube.position
    // }
    cube.mesh.position = cube.position
    cube.mesh.rotation = cube.rotation
}

main :: proc() {
    stb_image.set_flip_vertically_on_load(1)

    quad_vertices: []f32 = {
        // positions          // texture coords
        0.5,  0.5, 0.0,      1.0, 1.0,   // top right
        0.5, -0.5, 0.0,      1.0, 0.0,   // bottom right
        -0.5, -0.5, 0.0,      0.0, 0.0,   // bottom left
        -0.5,  0.5, 0.0,      0.0, 1.0    // top left 
    }

    quad_indices: []u32 = {
        0, 1, 3, // first triangle
        1, 2, 3  // second triangle
    }

    wireframe: bool = false
    triangles_color: [3]f32 = {0,0,0}
    
    // ------- Engine
    
    engine_init()
    
    // ---- IMGUI
    tool_bar_open: bool = true
    imgui.CHECKVERSION()
    imgui.create_context()
    io := imgui.get_io()
    io.config_flags |= {.Nav_Enable_Keyboard, .No_Mouse_Cursor_Change} // no cursor makes the glfw the source of truth, not imgui
    io.config_flags |= {.Docking_Enable}
    // if io.want_capture_mouse can be checked to check if mouse is on imgui
    
    // imgui.open
    imgui_glfw.init_for_open_gl(engine_state.window, true)
    imgui_gl.init("#version 330")
    
    dummy_cube: ^CubeTest = cube_test_create(engine.Vec3{2, 0, 2})
    defer cube_test_destroy(dummy_cube)

    // shader
    triangle_shader: ^engine.Shader = engine.shader_create("triangle.vert", "triangle.frag")
    defer gl.DeleteProgram(triangle_shader.shader_program)
    defer free(triangle_shader)

    view_matrix: engine.Mat4 = linalg.MATRIX4F32_IDENTITY
    view_translation: engine.Vec3 = {0.0, 0.0, -3.0} // we can use our typedefs
    view_matrix = linalg.matrix4_translate(view_translation)
    
    projection : engine.Mat4 = linalg.matrix4_perspective(math.to_radians(f32(45.0)), 800.0/600.0, 0.1, 100.0)

    ground_texture := engine.texture_create("textures/y2k_ground_2.png", engine.TextureFormat.RGB)
    defer free(ground_texture) // free out of scope

    // O sampler2D no shader não recebe pixels — recebe um índice de texture unit (slot).
    // Aqui dizemos: "quando o shader pedir 'ourTexture', leia do slot 0; 'awesomeTexture', do slot 1".
    // Isso só precisa ser feito uma vez, não a cada frame.
    gl.UseProgram(triangle_shader.shader_program)
    engine.shader_set_int(triangle_shader, "ourTexture", 0)
    // shader_set_int(triangle_shader, "awesomeTexture", 1)

    engine_state.main_camera = engine.camera_create_perspective(engine.Vec3{0,1,0})
    defer free(engine_state.main_camera)

    view_matrix = linalg.MATRIX4F32_IDENTITY
    
    delta_time: f64
    last_frame: f64
    
    for !glfw.WindowShouldClose(engine_state.window){
        current_frame := glfw.GetTime()
        delta_time = current_frame - last_frame
        last_frame = current_frame
        
        glfw.PollEvents()
        imgui_gl.new_frame()
        imgui_glfw.new_frame()
        imgui.new_frame()
        
        camera_speed : f32= 20 * f32(delta_time) // precision loss
       
        if glfw.GetKey(engine_state.window, glfw.KEY_ESCAPE) == glfw.PRESS {
            glfw.SetWindowShouldClose(engine_state.window, true)
        }
        
        if glfw.GetKey(engine_state.window, glfw.KEY_SPACE) == glfw.PRESS {
            wireframe = !wireframe
        }
        
        if glfw.GetKey(engine_state.window, glfw.KEY_W) == glfw.PRESS {
            engine_state.main_camera.position += camera_speed * engine_state.main_camera.forward
        }
        if glfw.GetKey(engine_state.window, glfw.KEY_S) == glfw.PRESS {
            engine_state.main_camera.position -= camera_speed * engine_state.main_camera.forward
        }
        if glfw.GetKey(engine_state.window, glfw.KEY_A) == glfw.PRESS {
            engine_state.main_camera.position -= camera_speed * engine_state.main_camera.right
        }
        if glfw.GetKey(engine_state.window, glfw.KEY_D) == glfw.PRESS {
            engine_state.main_camera.position += camera_speed * engine_state.main_camera.right
        }

        if glfw.GetKey(engine_state.window, glfw.KEY_TAB) == glfw.PRESS {
            mouse_captured = !mouse_captured
            glfw.SetInputMode(engine_state.window, glfw.CURSOR, mouse_captured ? glfw.CURSOR_DISABLED : glfw.CURSOR_NORMAL)
        }

       
        
        
        // must recalculate after chanfing engine_state.main_camera.forward
        engine_state.main_camera.right = linalg.normalize(linalg.cross(engine_state.main_camera.forward, engine.Vec3{0,1,0}))
        engine_state.main_camera.up = linalg.cross(engine_state.main_camera.right, engine_state.main_camera.forward)
        
        view_matrix = linalg.matrix4_look_at(
           engine_state.main_camera.position,
           engine_state.main_camera.position + engine_state.main_camera.forward,
           engine_state.main_camera.up
        )
        cube_test_update(dummy_cube)

        // :rendering
        gl.ClearColor(0.2, 0.3, 0.3, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

        if wireframe {
            gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
        } else {
            gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
        }

        engine.mesh_draw(dummy_cube.mesh, triangle_shader, &view_matrix, &projection, triangles_color)

        // ---- IMGUI RENDER
        imgui.begin("test panel", &tool_bar_open, imgui.Window_Flags{imgui.Window_Flag.Menu_Bar})

        if imgui.begin_menu_bar()
        {
            if imgui.begin_menu("File")
            {
                if imgui.menu_item("Open..", "Ctrl+O") { /* Do stuff */ }
                if imgui.menu_item("Save", "Ctrl+S")   { /* Do stuff */ }
                if imgui.menu_item("Close", "Ctrl+W")  { wireframe = !wireframe }
                imgui.end_menu();
            }
            imgui.end_menu_bar();
        }

        imgui.color_picker3("triangle colors", &triangles_color)
        if imgui.button("Wireframe") {
            wireframe = !wireframe
        }
        // imgui.vector_construct(&dummy_cube.position)
        imgui.drag_float3("Cube position", &dummy_cube.position, 0.01)
        imgui.drag_float3("Cube rotation", &dummy_cube.rotation, 0.1)
        imgui.end()


        imgui.render()
        imgui_gl.render_draw_data(imgui.get_draw_data())

        glfw.SwapBuffers(engine_state.window)

    }

    // gl.DeleteVertexArrays(1, &orange_triangle.VAO)
    // gl.DeleteBuffers(1, &orange_triangle.VBO)
    // gl.DeleteBuffers(1, &orange_triangle.EBO)

    engine_cleanup()
}

engine_init :: proc() {
    // debug
    glfw.SetErrorCallback(proc "c" (code: i32, desc: cstring) {
        context = runtime.default_context()
        fmt.printfln("GLFW error %d: %s", code, desc)
    })

    if !glfw.Init() {
        fmt.println("Failed to initialize GLFW")
        return
    }
    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
    
    engine_state.window = glfw.CreateWindow(800, 600, "OpenGL renderer", nil, nil)
    
    if engine_state.window == nil {
        fmt.printfln("Could not create window")
        glfw.Terminate();
        return
    }

    glfw.SetCursorPosCallback(engine_state.window, glfw_mouse_callback)
    
    glfw.MakeContextCurrent(engine_state.window)
    gl.load_up_to(int(3), 3, glfw.gl_set_proc_address) 
    gl.Viewport(0,0, 800, 600)
    gl.Enable(gl.DEPTH_TEST)
    glfw.SetInputMode(engine_state.window, glfw.CURSOR, glfw.CURSOR_DISABLED)
}

engine_cleanup :: proc() {
    imgui_gl.shutdown()
    imgui_glfw.shutdown()
    imgui.destroy_context()

    glfw.DestroyWindow(engine_state.window)
    glfw.Terminate()
}

// CursorPosProc é uma definicao de metodo com o #type
glfw_mouse_callback :: proc "c" (window: glfw.WindowHandle, mouse_x_pos: f64, mouse_y_pos: f64) {
    context = runtime.default_context()

    x_offset: f64 = mouse_x_pos - lastMouseX
    y_offset: f64 = lastMouseY - mouse_y_pos // reversed since y-coordinates range from bottom to to
    lastMouseX = mouse_x_pos
    lastMouseY = mouse_y_pos

    sensi: f64 = 0.01
    x_offset *= sensi
    y_offset *= sensi
    
    engine_state.main_camera.yaw += f32(x_offset)// precision loss
    engine_state.main_camera.pitch += f32(y_offset)
    
    engine_state.main_camera.direction.x = math.cos(linalg.to_radians(engine_state.main_camera.yaw)) * math.cos(linalg.to_radians(engine_state.main_camera.pitch))
    engine_state.main_camera.direction.y = math.sin(linalg.to_radians(engine_state.main_camera.pitch))
    engine_state.main_camera.direction.z = math.sin(linalg.to_radians(engine_state.main_camera.yaw)) * math.cos(linalg.to_radians(engine_state.main_camera.pitch))
    engine_state.main_camera.forward = linalg.normalize(engine_state.main_camera.direction)

    // fmt.println(x_offset, y_offset, engine_state.main_camera.yaw)
}