package main

import "core:fmt"
import "core:os"
import "core:strings"
import "base:runtime"
import "core:math/linalg"

import "vendor:glfw"
import gl "vendor:OpenGL"
import stb_image "vendor:stb/image"

TextureFormat :: enum u32 {
    RGB  = gl.RGB,
    RGBA = gl.RGBA,
}

Texture :: struct {
    id: u32
}

Triangle :: struct {
    VAO: u32, // VAO are like pipelines, hold instructions on how to get the mesh data
    VBO: u32,
    EBO: u32
}

Quad :: struct {
    vertices: []f32,
    textures: [dynamic]^Texture,
    VAO: u32,
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

quad_draw :: proc(quad: ^Quad, quad_shader: ^Shader, model_matrix: ^Mat4, view_matrix: ^Mat4, projection: ^Mat4, color: [3]f32) {

     gl.UseProgram(quad_shader.shader_program)
    shader_set_uniform4f(quad_shader, "ourColor", color)
    shader_set_matrix4f(quad_shader, "model", model_matrix)
    shader_set_matrix4f(quad_shader, "view", view_matrix)
    shader_set_matrix4f(quad_shader, "projection", projection)

    // A cada frame, colocamos cada textura no slot correto antes de desenhar.
    // ActiveTexture seleciona qual slot estamos configurando.
    // BindTexture coloca a textura nesse slot.
    // O shader então lê de cada slot pelo índice definido nos uniforms acima.
    // gl.ActiveTexture(gl.TEXTURE0)
    // gl.BindTexture(gl.TEXTURE_2D, ground_texture.id)

    // gl.ActiveTexture(gl.TEXTURE1)
    // gl.BindTexture(gl.TEXTURE_2D, awesome_texture.id)

    for texture, i in quad.textures {
        gl.ActiveTexture(gl.TEXTURE0 + u32(i))
        gl.BindTexture(gl.TEXTURE_2D, texture.id)
    }

    gl.BindVertexArray(quad.VAO) // loads the quad VAO so we now how to query its pipeline
    // glDrawArrays(GLenum mode, GLint first, GLsizei count)
    // Draws `count` vertices found in the currently bound vertex buffer object (or indirectly via a vertex array object).
    //   mode:  Specifies the kind of primitive to render (e.g. GL_TRIANGLES, GL_LINES, GL_POINTS ...)
    //   first: Specifies the starting index in the enabled arrays.
    //   count: Specifies the number of vertices to render.
    // gl.DrawArrays(gl.TRIANGLES, 0, 3)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, quad.EBO)
    gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
}

texture_create :: proc(texture_file: cstring, format: TextureFormat) -> ^Texture{
    new_texture := new(Texture)

    image_w, image_h, nr_channels: i32
    data := stb_image.load(texture_file, &image_w, &image_h, &nr_channels, 0)
    
    gl.GenTextures(1, &new_texture.id)
    gl.BindTexture(gl.TEXTURE_2D, new_texture.id)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, image_w, image_h, 0, u32(format), gl.UNSIGNED_BYTE, data) // envia os bytes pra GPU
    gl.GenerateMipmap(gl.TEXTURE_2D)
    stb_image.image_free(data) // bytes na CPU podem ser liberados, a GPU já tem sua cópia

    return new_texture;
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

shader_set_texture :: proc(shader: ^Shader, texture_uniform: string, texture_slot: i32) {
    // O sampler2D no shader não recebe pixels — recebe um índice de texture unit (slot).
    // Aqui dizemos: "quando o shader pedir 'ourTexture', leia do slot 0; 'awesomeTexture', do slot 1".
    // Isso só precisa ser feito uma vez, não a cada frame.
    gl.UseProgram(shader.shader_program)
    shader_set_int(shader, texture_uniform, texture_slot)
}