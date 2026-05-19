package main

import "core:terminal/ansi"
import "core:fmt"
import "base:runtime"
import "vendor:glfw"
import gl "vendor:OpenGL" 

main :: proc() {
    fmt.println("Hello, World!");


    triangle_vertices: []f32 = {
        0.5,  0.5, 0.0,  // top right
        0.5, -0.5, 0.0,  // bottom right
        -0.5, -0.5, 0.0,  // bottom left
        -0.5,  0.5, 0.0   // top left 
    }

    triangle_indices: []u32 = {
        0, 1, 3, // first triangle
        1, 2, 3  // second triangle
    }


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


    // we bind the VAO (Vertex Array Object) first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
    // A VAO is an object that encapsulates all of the state needed to specify vertex
    VAO: u32
    gl.GenVertexArrays(1, &VAO)
    gl.BindVertexArray(VAO)

    
    // VBO (Vertex Buffer Object): objeto que representa um buffer alocado na VRAM da GPU.
    // Armazena dados de vértices (posição, normal, UV, cor, etc.) diretamente na memória da GPU,
    // evitando transferências repetidas a cada frame.
    VBO: u32
    gl.GenBuffers(1, &VBO) // aloca o buffer object na GPU e retorna seu ID único
    
    // Vincula o VBO ao target ARRAY_BUFFER no estado global do OpenGL.
    // OpenGL opera como uma máquina de estados: todas as operações subsequentes sobre
    // ARRAY_BUFFER afetarão este VBO até que outro seja vinculado ou o target seja desvinculado.
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
    
    // Carrega os dados de vértices para o buffer atualmente vinculado ao ARRAY_BUFFER.
    // O último argumento define o padrão de uso: STATIC_DRAW (escrito uma vez, lido muitas vezes),
    // DYNAMIC_DRAW (atualizado frequentemente) ou STREAM_DRAW (escrito e lido uma única vez).
    gl.BufferData(gl.ARRAY_BUFFER, len(triangle_vertices) * size_of(f32), raw_data(triangle_vertices), gl.STATIC_DRAW)
    
    EBO: u32
    gl.GenBuffers(1, &EBO)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(triangle_indices) * size_of(u32), raw_data(triangle_indices), gl.STATIC_DRAW)


    // params, in order
    // first  (0) is the location of the vertex attribute in the shader (layout(location = 0))
    // second (3) is the number of components per vertex attribute (vec3 = 3)
    // third  (gl.FLOAT) is the data type of each component
    // fourth (gl.FALSE) specifies whether fixed-point data values should be normalized (true) or converted directly as integers (false) when accessed
    // fifth  (3 * size_of(f32)) is the byte offset between consecutive vertex attributes (the stride). Since our vertices are tightly packed, this is just the size of one vertex (3 floats)
    // sixth  (0) is the offset of the first component of the first vertex attribute in the buffer. Since our vertex data starts at the beginning of the buffer, this is 0 (or nil)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), 0)
    gl.EnableVertexAttribArray(0)

    vertex_shader: cstring = `#version 330 core
    layout (location = 0) in vec3 aPos;
    void main()
    {
        gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
    }`

    vertex_shader_comp: u32
    vertex_shader_comp = gl.CreateShader(gl.VERTEX_SHADER)
    comp_status: i32
    infoLog: [512]u8 // char array

    gl.ShaderSource(vertex_shader_comp, 1, &vertex_shader, nil)
    gl.CompileShader(vertex_shader_comp)

    gl.GetShaderiv(vertex_shader_comp, gl.COMPILE_STATUS, &comp_status)

    if comp_status == 0 {
        gl.GetShaderInfoLog(vertex_shader_comp, 512, nil, &infoLog[0])
        fmt.printfln("ERROR::SHADER::VERTEX::COMPILATION_FAILED\n")
        fmt.println(cstring(&infoLog[0]))
    }


    // FRAG SAHDER

    frag_shader : cstring = `#version 330 core
    out vec4 FragColor;
    void main()
    {
        FragColor = vec4(1.0, 0.5, 0.2, 1.0);
    }`

    frag_shader_comp: u32
    frag_shader_comp = gl.CreateShader(gl.FRAGMENT_SHADER)
    gl.ShaderSource(frag_shader_comp, 1, &frag_shader, nil)
    gl.CompileShader(frag_shader_comp)
    gl.GetShaderiv(frag_shader_comp, gl.COMPILE_STATUS, &comp_status)

    if comp_status == 0 {
        gl.GetShaderInfoLog(frag_shader_comp, 512, nil, &infoLog[0])
        fmt.printfln("ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n")
        fmt.println(cstring(&infoLog[0]))
    }


    shader_pogram: u32
    shader_pogram = gl.CreateProgram()
    gl.AttachShader(shader_pogram, vertex_shader_comp)
    gl.AttachShader(shader_pogram, frag_shader_comp)
    gl.LinkProgram(shader_pogram)

    gl.DeleteShader(vertex_shader_comp)
    gl.DeleteShader(frag_shader_comp)


    for !glfw.WindowShouldClose(window){
        glfw.PollEvents()

        if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS {
            glfw.SetWindowShouldClose(window, true)
        }

        if glfw.GetKey(window, glfw.KEY_W) == glfw.PRESS {
            fmt.printfln("W")
        }

        gl.ClearColor(0.2, 0.3, 0.3, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        gl.UseProgram(shader_pogram)
        gl.BindVertexArray(VAO)
        // gl.DrawArrays(gl.TRIANGLES, 0, 3)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)
        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)

        glfw.SwapBuffers(window)
    }


    glfw.Terminate();
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