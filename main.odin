package main

import "core:terminal/ansi"
import "core:fmt"
import "base:runtime"
import "vendor:glfw"
import gl "vendor:OpenGL" 


import "core:os"
import "core:strings"


Triangle :: struct {
    VAO: u32, // VAO are like pipelines, hold instructions on how to get the mesh data
    VBO: u32,
    EBO: u32
}

Shader :: struct {
    shader_program: u32 // used to bind to rendering
}

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


    // triangle_vertices: []f32 = {
    //     0.5,  0.5, 0.0,  // top right
    //     0.5, -0.5, 0.0,  // bottom right
    //     -0.5, -0.5, 0.0,  // bottom left
    //     -0.5,  0.5, 0.0   // top left 
    // }

    // triangle_indices: []u32 = {
    //     0, 1, 3, // first triangle
    //     1, 2, 3  // second triangle
    // }

    // size is not known at compile time, so its a slice, defer the freeing
    triangle_vertices: []f32 = {
        -0.1,  0.2, 0.0,  // top
        0.0, -0.1, 0.0,  // bottom right
        -0.2, -0.1, 0.0,  // bottom left
    } 
    defer delete(triangle_vertices) // free for objects and structs, delete for slices and string (buffers of data)

    triangle_two_vertices: []f32 = {
        0.1,  0.2, 0.0,  // top
        0.0, -0.1, 0.0,  // bottom right
        0.2, -0.1, 0.0,  // bottom left
    }
    defer delete(triangle_two_vertices)

    wireframe: bool = false

    // ------- Engine

    engine_init()

    window: glfw.WindowHandle = glfw.CreateWindow(800, 600, "OpenGL renderer", nil, nil)

    if window == nil {
        fmt.printfln("Could not create window")
        glfw.Terminate();
        return
    }

    glfw.MakeContextCurrent(window)
    gl.load_up_to(int(3), 3, glfw.gl_set_proc_address) 
    gl.Viewport(0,0, 800, 600)


    orange_triangle: ^Triangle = triangle_create(triangle_vertices, {})
    defer free(orange_triangle) // defers the freeing when we go out of scope (ending program in this case)
    triangle_two: ^Triangle = triangle_create(triangle_two_vertices, {})
    defer free(triangle_two)

    // shader
    orange_shader: ^Shader = shader_create("default.vert", "default.frag")
    defer gl.DeleteProgram(orange_shader.shader_program)
    defer free(orange_shader)

    yellow_shader: ^Shader = shader_create("default.vert", "yellow.frag")
    defer gl.DeleteProgram(yellow_shader.shader_program)
    defer free(yellow_shader)


    for !glfw.WindowShouldClose(window){
        glfw.PollEvents()

        if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS {
            glfw.SetWindowShouldClose(window, true)
        }

        if glfw.GetKey(window, glfw.KEY_SPACE) == glfw.PRESS {
            wireframe = !wireframe
        }

        if glfw.GetKey(window, glfw.KEY_W) == glfw.PRESS {
            fmt.printfln("W")
        }

        gl.ClearColor(0.2, 0.3, 0.3, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        if wireframe {
            gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
        } else {
            gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
        }

        gl.UseProgram(orange_shader.shader_program)
        gl.BindVertexArray(orange_triangle.VAO)
        // glDrawArrays(GLenum mode, GLint first, GLsizei count)
        // Draws `count` vertices found in the currently bound vertex buffer object (or indirectly via a vertex array object).
        //   mode:  Specifies the kind of primitive to render (e.g. GL_TRIANGLES, GL_LINES, GL_POINTS ...)
        //   first: Specifies the starting index in the enabled arrays.
        //   count: Specifies the number of vertices to render.
        gl.DrawArrays(gl.TRIANGLES, 0, 3)
        // gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, orange_triangle.EBO)
        // gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)

        // draw yellow triangle
        gl.UseProgram(yellow_shader.shader_program)
        gl.BindVertexArray(triangle_two.VAO)
        gl.DrawArrays(gl.TRIANGLES, 0, 3)

        glfw.SwapBuffers(window)
    }

    defer gl.DeleteVertexArrays(1, &orange_triangle.VAO)
    defer gl.DeleteBuffers(1, &orange_triangle.VBO)
    defer gl.DeleteBuffers(1, &orange_triangle.EBO)
        // defer gl.DeleteProgram(shader_pogram)

    defer glfw.DestroyWindow(window)
    defer glfw.Terminate()
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
}