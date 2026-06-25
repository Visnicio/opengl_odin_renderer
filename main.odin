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
Vec2 :: linalg.Vector2f32

EngineState :: struct {
    window: glfw.WindowHandle
}

engine_state: EngineState

// Camera :: struct {
//     position: Vec3,
//     direction: Vec3,

//     // pointing directions
//     right: Vec3,
//     up: Vec3,
//     forward: Vec3 // usually -Z, like godot

//     // matrices
//     view_mat: Mat4,
//     projection_mat: Mat4,
//     model: Mat4,
// }

// camera_create :: proc() -> ^Camera {
//     new_camera: Camera = {
//         right
//     }
// }

CubeTest :: struct {
    // quads: [6]^Quad,
    mesh: ^Mesh,
    position: Vec3,
    rotation: Vec3
}

cube_test_create :: proc(position: Vec3) -> ^CubeTest {

    //        v6 ───────────── v7
    //        /│               /│
    //       / │              / │
    //      /  │             /  │
    //    v4 ──┼─────────── v5   │
    //     │   │            │    │
    //     │   │            │    │
    //     │  v2 ───────────┼── v3
    //     │  /              │  /
    //     │ /               │ /
    //     │/                │/
    //    v0 ──────────────  v1
    //
    cube_vertices: []VertexData = {

        { // 0
            position = {-0.5,  0.5, -0.5},
            color = {1, 1, 1},
            uv = {0, 1}
        },

        { // 1
            position = {0.5,  0.5, -0.5},
            color = {1, 1, 1},
            uv = {1, 1}
        },

        { // 2
            position = {-0.5,  0.5, 0.5},
            color = {1, 1, 1},
            uv = {0, 0}
        },

        { // 3 
            position = {0.5,  0.5, 0.5},
            color = {1, 1, 1},
            uv = {1, 0}
        },

        { // 4 - top left corner
            position = {-0.5,  -0.5, -0.5},
            color = {1, 1, 1},
            uv = {0, 0}
        },

        { // 5
            position = {0.5,  -0.5, -0.5},
            color = {1, 1, 1},
            uv = {0, 1}
        },

        { // 6
            position = {-0.5,  -0.5, 0.5},
            color = {1, 1, 1},
            uv = {1, 0}
        },

        {
            position = {0.5,  -0.5, 0.5},
            color = {1, 1, 1},
            uv = {1, 1}
        }
    }

    cube_indides: []u32 = {
        0, 1, 2, // bottom-face-first-triangle
        1, 2, 3,  // bottom face
        0, 1, 4, // front face
        1, 4, 5, // front face
        4, 5, 6, // top face
        5, 6, 7, // top face
        2, 3, 6, // back face // wrong uv, change order
        3, 6, 7, // back face
        0, 2, 4, // left face
        2, 4, 6, // left face
        1, 3, 5, // right face // wrong uv
        3, 5, 7 // right face
    }

    new_cube: ^CubeTest = new(CubeTest)
    new_cube.position = position
    new_cube.rotation = Vec3{0, 0, 0}
    new_cube.mesh = mesh_create(cube_vertices, cube_indides)

    return new_cube
}

// calls this as defer soon after creating the cube if needed, frees the cube, and quads, and handles quad freeing
cube_test_destroy :: proc(c: ^CubeTest) {
    mesh_destroy(c.mesh)
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

    // quad_tex_coords: []f32 = {
    //     1.0, 1.0, // top right
    //     1.0, 0.0, // bottom right
    //     0.0, 0.0, // bottom left
    //     0.0, 1.0  // top left
    // }

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
    
    dummy_cube: ^CubeTest = cube_test_create(Vec3{2, 0, 2})
    defer cube_test_destroy(dummy_cube)

    quad: ^Quad = quad_create(quad_vertices, quad_indices)
    defer quad_destroy(quad)

    second_quad: ^Quad = quad_create(quad_vertices, quad_indices)
    second_quad.position = {-1.0, 0.0, -1.0}
    defer quad_destroy(second_quad)

    // shader
    triangle_shader: ^Shader = shader_create("triangle.vert", "triangle.frag")
    defer gl.DeleteProgram(triangle_shader.shader_program)
    defer free(triangle_shader)

    quad.model_mat = linalg.matrix4_rotate(math.to_radians(f32(-55)), linalg.Vector3f32{1.0, 0.0, 0.0})

    view_matrix: Mat4 = linalg.MATRIX4F32_IDENTITY
    view_translation: Vec3 = {0.0, 0.0, -3.0} // we can use our typedefs
    view_matrix = linalg.matrix4_translate(view_translation)
    
    projection : Mat4 = linalg.matrix4_perspective(math.to_radians(f32(45.0)), 800.0/600.0, 0.1, 100.0)

    ground_texture := texture_create("textures/y2k_ground_2.png", TextureFormat.RGB)
    defer free(ground_texture) // free out of scope

    // awesome_texture := texture_create("textures/awesomeface.png", TextureFormat.RGBA)
    // defer free(awesome_texture)

    append(&quad.textures, ground_texture)
    // append(&quad.textures, awesome_texture)
  

    // O sampler2D no shader não recebe pixels — recebe um índice de texture unit (slot).
    // Aqui dizemos: "quando o shader pedir 'ourTexture', leia do slot 0; 'awesomeTexture', do slot 1".
    // Isso só precisa ser feito uma vez, não a cada frame.
    gl.UseProgram(triangle_shader.shader_program)
    shader_set_int(triangle_shader, "ourTexture", 0)
    // shader_set_int(triangle_shader, "awesomeTexture", 1)

    camera_pos: Vec3 = {0, 0, 3}
    camera_target : Vec3 = {0,0,0}
    camera_direction: Vec3 = linalg.normalize(camera_pos - camera_target)
    world_up : Vec3 = {0, 1, 0}
    camera_right : Vec3 = linalg.normalize(linalg.cross(world_up, camera_direction))
    camera_up: Vec3 = linalg.cross(camera_direction, camera_right)
    camera_front: Vec3 = {0,0,-1}

    view_matrix = linalg.MATRIX4F32_IDENTITY
    
    delta_time: f64
    last_frame: f64

    camera_pitch: f32 = 0
    camera_yaw: f32 = -90 // default looking towards -z
    
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
            camera_pos += camera_speed * camera_front
        }
        if glfw.GetKey(engine_state.window, glfw.KEY_S) == glfw.PRESS {
            camera_pos -= camera_speed * camera_front
        }
        if glfw.GetKey(engine_state.window, glfw.KEY_A) == glfw.PRESS {
            camera_pos += camera_speed * camera_right
        }
        if glfw.GetKey(engine_state.window, glfw.KEY_D) == glfw.PRESS {
            camera_pos -= camera_speed * camera_right
        }

        // rotate camera
        if glfw.GetKey(engine_state.window, glfw.KEY_E) == glfw.PRESS {
            camera_yaw += camera_speed
        }
        if glfw.GetKey(engine_state.window, glfw.KEY_Q) == glfw.PRESS {
            camera_yaw -= camera_speed
        }

         
        camera_direction.x = math.cos(linalg.to_radians(camera_yaw)) * math.cos(linalg.to_radians(camera_pitch))
        camera_direction.y = math.sin(linalg.to_radians(camera_pitch))
        camera_direction.z = math.sin(linalg.to_radians(camera_yaw)) * math.cos(linalg.to_radians(camera_pitch))
        camera_front = linalg.normalize(camera_direction)
        // must recalculate after chanfing camera_front
        camera_right = linalg.normalize(linalg.cross(camera_front, world_up))
        camera_up = linalg.cross(camera_direction, camera_right)
        
        view_matrix = linalg.matrix4_look_at(
           camera_pos,
           camera_pos + camera_front,
           camera_up
        )
        // up_vec: Vec3 = {0.5, 1, 0}
        quad.model_mat = linalg.matrix4_rotate(f32(glfw.GetTime()) * math.to_radians(f32(50)), world_up)

        cube_test_update(dummy_cube)

        // :rendering
        gl.ClearColor(0.2, 0.3, 0.3, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

        if wireframe {
            gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
        } else {
            gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
        }

        //quad_draw(quad, triangle_shader, &view_matrix, &projection, triangles_color)
        //quad_draw(second_quad, triangle_shader, &view_matrix, &projection, triangles_color)

        // for q in dummy_cube.quads {
        //     if q != nil {
        //         quad_draw(q, triangle_shader, &view_matrix, &projection, triangles_color)
        //     }
        // }
        mesh_draw(dummy_cube.mesh, triangle_shader, &view_matrix, &projection, triangles_color)

        // ---- IMGUI RENDER
        imgui.begin("test panel")
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
    
    glfw.MakeContextCurrent(engine_state.window)
    gl.load_up_to(int(3), 3, glfw.gl_set_proc_address) 
    gl.Viewport(0,0, 800, 600)
    gl.Enable(gl.DEPTH_TEST)
}

engine_cleanup :: proc() {
    imgui_gl.shutdown()
    imgui_glfw.shutdown()
    imgui.destroy_context()

    glfw.DestroyWindow(engine_state.window)
    glfw.Terminate()
}