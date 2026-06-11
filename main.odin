package main

import "core:math"
import "core:fmt"
import "core:os"
import "core:strings"
import "base:runtime"
import "core:math/linalg"

import "vendor:glfw"
import gl "vendor:OpenGL"
import stb_image "vendor:stb/image"

import imgui "odin-imgui"
import imgui_gl "odin-imgui/imgui_impl_opengl3"
import imgui_glfw "odin-imgui/imgui_impl_glfw"


Mat4 :: linalg.Matrix4f32
Vec3 :: linalg.Vector3f32

EngineState :: struct {
    window: glfw.WindowHandle
}

engine_state: EngineState

main :: proc() {
    fmt.println("Hello, World!");

    stb_image.set_flip_vertically_on_load(1)

    // quad_vertices: []f32 = {
    //     // positions          // colors           // texture coords
    //     0.5,  0.5, 0.0,   1.0, 0.0, 0.0,   1.0, 1.0,   // top right
    //     0.5, -0.5, 0.0,   0.0, 1.0, 0.0,   1.0, 0.0,   // bottom right
    //     -0.5, -0.5, 0.0,   0.0, 0.0, 1.0,   0.0, 0.0,   // bottom left
    //     -0.5,  0.5, 0.0,   1.0, 1.0, 0.0,   0.0, 1.0    // top left 
    // }
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

    quad_tex_coords: []f32 = {
        1.0, 1.0, // top right
        1.0, 0.0, // bottom right
        0.0, 0.0, // bottom left
        0.0, 1.0  // top left
    }

    wireframe: bool = false
    triangles_color: [3]f32 = {0,0,0}
    
    // ------- Engine
    
    engine_init()
    
    // ---- IMGUI
    imgui.CHECKVERSION()
    imgui.create_context()
    io := imgui.get_io()
    io.config_flags |= {.Nav_Enable_Keyboard}
    io.config_flags |= {.Docking_Enable}
    
    // imgui.open
    imgui_glfw.init_for_open_gl(engine_state.window, true)
    imgui_gl.init("#version 330")


    quad: ^Quad = quad_create(quad_vertices, quad_indices)
    defer free(quad)

    // shader
    triangle_shader: ^Shader = shader_create("triangle.vert", "triangle.frag")
    defer gl.DeleteProgram(triangle_shader.shader_program)
    defer free(triangle_shader)

    model_matrix: Mat4 = linalg.MATRIX4F32_IDENTITY // initialize identity matrix
    model_matrix = linalg.matrix4_rotate(math.to_radians(f32(-55)), linalg.Vector3f32{1.0, 0.0, 0.0})
    
    view_matrix: Mat4 = linalg.MATRIX4F32_IDENTITY
    view_translation: Vec3 = {0.0, 0.0, -3.0} // we can use our typedefs
    view_matrix = linalg.matrix4_translate(view_translation)
    
    projection : Mat4 = linalg.matrix4_perspective(math.to_radians(f32(45.0)), 800.0/600.0, 0.1, 100.0)


    ground_texture := texture_create("textures/y2k_ground_2.png", TextureFormat.RGB)
    defer free(ground_texture) // free out of scope

    awesome_texture := texture_create("textures/awesomeface.png", TextureFormat.RGBA)
    defer free(awesome_texture)

    append(&quad.textures, ground_texture)
    // append(&quad.textures, awesome_texture)
  

    // O sampler2D no shader não recebe pixels — recebe um índice de texture unit (slot).
    // Aqui dizemos: "quando o shader pedir 'ourTexture', leia do slot 0; 'awesomeTexture', do slot 1".
    // Isso só precisa ser feito uma vez, não a cada frame.
    gl.UseProgram(triangle_shader.shader_program)
    shader_set_int(triangle_shader, "ourTexture", 0)
    shader_set_int(triangle_shader, "awesomeTexture", 1)


    for !glfw.WindowShouldClose(engine_state.window){
        glfw.PollEvents()
        imgui_gl.new_frame()
        imgui_glfw.new_frame()
        imgui.new_frame()

        if glfw.GetKey(engine_state.window, glfw.KEY_ESCAPE) == glfw.PRESS {
            glfw.SetWindowShouldClose(engine_state.window, true)
        }

        if glfw.GetKey(engine_state.window, glfw.KEY_SPACE) == glfw.PRESS {
            wireframe = !wireframe
        }

        if glfw.GetKey(engine_state.window, glfw.KEY_W) == glfw.PRESS {
            fmt.printfln("W")
        }

        up_vec: Vec3 = {0.5, 1, 0}
        model_matrix = linalg.matrix4_rotate(f32(glfw.GetTime()) * math.to_radians(f32(50)), up_vec)

        gl.ClearColor(0.2, 0.3, 0.3, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        if wireframe {
            gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
        } else {
            gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
        }

        quad_draw(quad, triangle_shader, &model_matrix, &view_matrix, &projection, triangles_color)

        // ---- IMGUI RENDER
        imgui.begin("test panel")
        imgui.color_picker3("triangle colors", &triangles_color)
        if imgui.button("Wireframe") {
            wireframe = !wireframe
        }
        imgui.end()


        imgui.render()
        imgui_gl.render_draw_data(imgui.get_draw_data())

        glfw.SwapBuffers(engine_state.window)

    }

    // gl.DeleteVertexArrays(1, &orange_triangle.VAO)
    // gl.DeleteBuffers(1, &orange_triangle.VBO)
    // gl.DeleteBuffers(1, &orange_triangle.EBO)
    gl.DeleteVertexArrays(1, &quad.VAO)
    gl.DeleteBuffers(1, &quad.VBO)
    gl.DeleteBuffers(1, &quad.EBO)

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

    glfw.MakeContextCurrent(engine_state.window)
    gl.load_up_to(int(3), 3, glfw.gl_set_proc_address) 
    gl.Viewport(0,0, 800, 600)
}

engine_cleanup :: proc() {
    imgui_gl.shutdown()
    imgui_glfw.shutdown()
    imgui.destroy_context()

    glfw.DestroyWindow(engine_state.window)
    glfw.Terminate()
}