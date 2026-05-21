package main

import "core:math"
import "core:fmt"
import "core:os"
import "core:strings"
import "base:runtime"
import "core:math/linalg"

import "vendor:glfw"
import gl "vendor:OpenGL" 

import imgui "odin-imgui"
import imgui_gl "odin-imgui/imgui_impl_opengl3"
import imgui_glfw "odin-imgui/imgui_impl_glfw"

import stb_image "vendor:stb/image"

Mat4 :: linalg.Matrix4f32
Vec3 :: linalg.Vector3f32

Triangle :: struct {
    VAO: u32, // VAO are like pipelines, hold instructions on how to get the mesh data
    VBO: u32,
    EBO: u32
}

Quad :: struct {
    vertices: []f32,
    VAO: u32,
    VBO: u32,
    EBO: u32
}

Shader :: struct {
    shader_program: u32 // used to bind to rendering
}

EngineState :: struct {
    window: glfw.WindowHandle
}

engine_state: EngineState

triangle_create :: proc(vertices: []f32, indices: []u32) -> ^Triangle {
    new_triangle := new(Triangle) // ALLOCATES ON HEAP, NEED TO FREE LATER
    gl.GenVertexArrays(1, &new_triangle.VAO)

    gl.BindVertexArray(new_triangle.VAO) // binds to configure

    gl.GenBuffers(1, &new_triangle.VBO)
    // Vincula o VBO ao target ARRAY_BUFFER no estado global do OpenGL.
    // OpenGL opera como uma máquina de estados: todas as operações subsequentes sobre
    // ARRAY_BUFFER afetarão este VBO até que outro seja vinculado ou o target seja desvinculado.
    gl.BindBuffer(gl.ARRAY_BUFFER, new_triangle.VBO)
    
    // Carrega os dados de vértices para o buffer atualmente vinculado ao ARRAY_BUFFER.
    // O último argumento define o padrão de uso: STATIC_DRAW (escrito uma vez, lido muitas vezes),
    // DYNAMIC_DRAW (atualizado frequentemente) ou STREAM_DRAW (escrito e lido uma única vez).
    gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(f32), raw_data(vertices), gl.STATIC_DRAW)


    gl.GenBuffers(1, &new_triangle.EBO)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, new_triangle.EBO)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(u32), raw_data(indices), gl.STATIC_DRAW)


    // Attach eveything to the VAO
    // params, in order
    // first  (0) is the location of the vertex attribute in the shader (layout(location = 0))
    // second (3) is the number of components per vertex attribute (vec3 = 3)
    // third  (gl.FLOAT) is the data type of each component
    // fourth (gl.FALSE) specifies whether fixed-point data values should be normalized (true) or converted directly as integers (false) when accessed
    // fifth  (3 * size_of(f32)) is the byte offset between consecutive vertex attributes (the stride). Since our vertices are tightly packed, this is just the size of one vertex (3 floats)
    // sixth  (0) is the offset of the first component of the first vertex attribute in the buffer. Since our vertex data starts at the beginning of the buffer, this is 0 (or nil)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), 0)
    gl.EnableVertexAttribArray(0)

    return new_triangle
}

quad_create :: proc(vertices: []f32, indices: []u32) -> ^Quad {
    new_quad := new(Quad) // ALLOCATES ON HEAP, NEED TO FREE LATER
    gl.GenVertexArrays(1, &new_quad.VAO)

    gl.BindVertexArray(new_quad.VAO) // binds to configure

    gl.GenBuffers(1, &new_quad.VBO)
    // Vincula o VBO ao target ARRAY_BUFFER no estado global do OpenGL.
    // OpenGL opera como uma máquina de estados: todas as operações subsequentes sobre
    // ARRAY_BUFFER afetarão este VBO até que outro seja vinculado ou o target seja desvinculado.
    gl.BindBuffer(gl.ARRAY_BUFFER, new_quad.VBO)
    
    // Carrega os dados de vértices para o buffer atualmente vinculado ao ARRAY_BUFFER.
    // O último argumento define o padrão de uso: STATIC_DRAW (escrito uma vez, lido muitas vezes),
    // DYNAMIC_DRAW (atualizado frequentemente) ou STREAM_DRAW (escrito e lido uma única vez).
    gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(f32), raw_data(vertices), gl.STATIC_DRAW)


    gl.GenBuffers(1, &new_quad.EBO)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, new_quad.EBO)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(u32), raw_data(indices), gl.STATIC_DRAW)


    // Attach eveything to the VAO
    // params, in order
    // first  (0) is the location of the vertex attribute in the shader (layout(location = 0))
    // second (3) is the number of components per vertex attribute (vec3 = 3)
    // third  (gl.FLOAT) is the data type of each component
    // fourth (gl.FALSE) specifies whether fixed-point data values should be normalized (true) or converted directly as integers (false) when accessed
    // fifth  (3 * size_of(f32)) is the byte offset between consecutive vertex attributes (the stride). Since our vertices are tightly packed, this is just the size of one vertex (3 floats)
    // sixth  (0) is the offset of the first component of the first vertex attribute in the buffer. Since our vertex data starts at the beginning of the buffer, this is 0 (or nil)
    // attrib 0: posição (xyz) — 3 floats, stride 5 floats, offset 0
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * size_of(f32), 0)
    gl.EnableVertexAttribArray(0)

    // attrib 1: UV (uv) — 2 floats, mesmo stride, offset de 3 floats (pula a posição)
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * size_of(f32), uintptr(3 * size_of(f32)))
    gl.EnableVertexAttribArray(1)

    return new_quad
}

shader_create :: proc(vertex_path: string, fragment_path: string) -> ^Shader {
    new_shader := new(Shader)

    vertex_source, err := os.read_entire_file(vertex_path, context.temp_allocator) 
    if err != nil {
        fmt.eprintf("Error parsing vertex source file")
    }
    vertex_src: cstring = strings.clone_to_cstring(string(vertex_source))

    vertex_shader_comp: u32
    vertex_shader_comp = gl.CreateShader(gl.VERTEX_SHADER)
    comp_status: i32
    infoLog: [512]u8 // char array

    gl.ShaderSource(vertex_shader_comp, 1, &vertex_src, nil)
    gl.CompileShader(vertex_shader_comp)
    gl.GetShaderiv(vertex_shader_comp, gl.COMPILE_STATUS, &comp_status)

    if comp_status == 0 {
        gl.GetShaderInfoLog(vertex_shader_comp, 512, nil, &infoLog[0])
        fmt.printfln("ERROR::SHADER::VERTEX::COMPILATION_FAILED\n")
        fmt.println(cstring(&infoLog[0]))
    }

    frag_source, err_Frag := os.read_entire_file(fragment_path, context.temp_allocator) 
    if err_Frag != nil {
        fmt.eprintf("Error parsing vertex source file")
    }
    frag_src: cstring = strings.clone_to_cstring(string(frag_source))
   
    frag_shader_comp: u32
    frag_shader_comp = gl.CreateShader(gl.FRAGMENT_SHADER)
    gl.ShaderSource(frag_shader_comp, 1, &frag_src, nil)
    gl.CompileShader(frag_shader_comp)
    gl.GetShaderiv(frag_shader_comp, gl.COMPILE_STATUS, &comp_status)

    if comp_status == 0 {
        gl.GetShaderInfoLog(frag_shader_comp, 512, nil, &infoLog[0])
        fmt.printfln("ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n")
        fmt.println(cstring(&infoLog[0]))
    }

    new_shader.shader_program = gl.CreateProgram()
    gl.AttachShader(new_shader.shader_program, vertex_shader_comp)
    gl.AttachShader(new_shader.shader_program, frag_shader_comp)
    gl.LinkProgram(new_shader.shader_program)

    gl.DeleteShader(vertex_shader_comp)
    gl.DeleteShader(frag_shader_comp)

   

    return new_shader
}

shader_set_uniform4f :: proc(shader: ^Shader, uniform_name: string, value: [3]f32) {
    uniformLocation := gl.GetUniformLocation(shader.shader_program, strings.clone_to_cstring((uniform_name)))
    gl.UseProgram(shader.shader_program)
    gl.Uniform4f(uniformLocation, value.x, value.y, value.z, 1.0) // swizilling is pretty cool
}

shader_set_matrix4f :: proc(shader: ^Shader, matrix_uniform_name: string, value: ^Mat4) {
    uniformLocation := gl.GetUniformLocation(shader.shader_program, strings.clone_to_cstring((matrix_uniform_name)))
    gl.UseProgram(shader.shader_program)
    gl.UniformMatrix4fv(uniformLocation, 1, gl.FALSE, linalg.to_ptr(value))
}

shader_set_int :: proc(shader: ^Shader, uniform_name: string, value: i32) {
    uniformLocation := gl.GetUniformLocation(shader.shader_program, strings.clone_to_cstring((uniform_name)))
    gl.UseProgram(shader.shader_program)
    gl.Uniform1i(uniformLocation, value)
}

// whenver we return string, structs or slices, they are allocated on the heap, we need to manually free them later
// read_all_from_file :: proc(filepath: string) -> string {
//     data, ok := os.read_entire_file(filepath, context.allocator)

//     if ok == 0 {
//         fmt.printfln("Failed to read file: %s", filepath)
//         return ""
//     }
//     defer delete(data, context.allocator) // defer the freeing of the data until we go out of scope (end of program in this case)
// }

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

    // size is not known at compile time, so its a slice, defer the freeing
    // triangle_vertices: []f32 = {
    //     -0.1,  0.2, 0.0,  // top
    //     0.0, -0.1, 0.0,  // bottom right
    //     -0.2, -0.1, 0.0,  // bottom left
    // } 
    // defer delete(triangle_vertices) // free for objects and structs, delete for slices and string (buffers of data)

    // triangle_two_vertices: []f32 = {
    //     0.1,  0.2, 0.0,  // top
    //     0.0, -0.1, 0.0,  // bottom right
    //     0.2, -0.1, 0.0,  // bottom left
    // }
    // defer delete(triangle_two_vertices)

    wireframe: bool = false
    triangles_color: [3]f32 = {0,0,0}
    
    // ------- Engine
    
    engine_init()
    
    // ---- IMGUI
    imgui.CHECKVERSION()
    imgui.create_context()
    io := imgui.get_io()
    // if io == nil {
    //     fmt.eprint("Could not locate ImGUI IO")
    //     return
    // }
    io.config_flags |= {.Nav_Enable_Keyboard}
    // // io.config_flags |= {.Nav_Enable_Keyboard}
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

    // MATH shi
    // vector : linalg.Vector4f32 = {1.0, 0.0, 0.0, 1.0} // I should typedef this Vec3 :: linalg.Vector3f32 Mat4 :: linalg.Matrix4f32
    // translation := linalg.MATRIX4F32_IDENTITY // initialize identity matrix
    // translation = linalg.matrix4_translate(linalg.Vector3f32{1.0, 1.0, 0.0})
    // fmt.printf("%v\n", translation)

    // trans := linalg.MATRIX4F32_IDENTITY
    // trans = linalg.matrix4_rotate_f32(math.to_radians(f32(90.0)), linalg.Vector3f32{0.0, 0.0, 1.0})
    // trans = linalg.matrix4_scale_f32(linalg.Vector3f32{0.5, 0.5, 0.5})

    model_matrix: Mat4 = linalg.MATRIX4F32_IDENTITY // initialize identity matrix
    model_matrix = linalg.matrix4_rotate(math.to_radians(f32(-55)), linalg.Vector3f32{1.0, 0.0, 0.0})
    
    view_matrix: Mat4 = linalg.MATRIX4F32_IDENTITY
    view_translation: Vec3 = {0.0, 0.0, -3.0} // we can use our typedefs
    view_matrix = linalg.matrix4_translate(view_translation)
    
    projection : Mat4 = linalg.matrix4_perspective(math.to_radians(f32(45.0)), 800.0/600.0, 0.1, 100.0)


    // TEXTURE
    // Os bytes da imagem são carregados da CPU pra GPU via TexImage2D.
    // Depois disso, a CPU não precisa mais dos dados — só o ID da textura importa.
    image_w, image_h, nr_channels: i32
    data := stb_image.load("textures/y2k_ground_2.png", &image_w, &image_h, &nr_channels, 0)

    texture: u32
    gl.GenTextures(1, &texture)
    gl.BindTexture(gl.TEXTURE_2D, texture)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, image_w, image_h, 0, gl.RGB, gl.UNSIGNED_BYTE, data) // envia os bytes pra GPU
    gl.GenerateMipmap(gl.TEXTURE_2D)
    stb_image.image_free(data) // bytes na CPU podem ser liberados, a GPU já tem sua cópia

    data = stb_image.load("textures/awesomeface.png", &image_w, &image_h, &nr_channels, 0)
    awesome_face_texture: u32
    gl.GenTextures(1, &awesome_face_texture)
    gl.BindTexture(gl.TEXTURE_2D, awesome_face_texture)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, image_w, image_h, 0, gl.RGBA, gl.UNSIGNED_BYTE, data) // envia os bytes pra GPU
    gl.GenerateMipmap(gl.TEXTURE_2D)
    stb_image.image_free(data)

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

        gl.UseProgram(triangle_shader.shader_program)
        shader_set_uniform4f(triangle_shader, "ourColor", triangles_color)
        shader_set_matrix4f(triangle_shader, "model", &model_matrix)
        shader_set_matrix4f(triangle_shader, "view", &view_matrix)
        shader_set_matrix4f(triangle_shader, "projection", &projection)

        // A cada frame, colocamos cada textura no slot correto antes de desenhar.
        // ActiveTexture seleciona qual slot estamos configurando.
        // BindTexture coloca a textura nesse slot.
        // O shader então lê de cada slot pelo índice definido nos uniforms acima.
        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_2D, texture)

        gl.ActiveTexture(gl.TEXTURE1)
        gl.BindTexture(gl.TEXTURE_2D, awesome_face_texture)

        gl.BindVertexArray(quad.VAO)
        // glDrawArrays(GLenum mode, GLint first, GLsizei count)
        // Draws `count` vertices found in the currently bound vertex buffer object (or indirectly via a vertex array object).
        //   mode:  Specifies the kind of primitive to render (e.g. GL_TRIANGLES, GL_LINES, GL_POINTS ...)
        //   first: Specifies the starting index in the enabled arrays.
        //   count: Specifies the number of vertices to render.
        // gl.DrawArrays(gl.TRIANGLES, 0, 3)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, quad.EBO)
        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)

        // ---- IMGUI RENDER
        imgui.begin("test panel")
        imgui.color_picker3("triangle colors", &triangles_color)
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