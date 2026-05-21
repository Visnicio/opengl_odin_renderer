#version 330 core

in vec2 TexCoord;

out vec4 FragColor;

uniform vec4 ourColor;
uniform sampler2D ourTexture;
uniform sampler2D awesomeTexture;

void main()
{
    // FragColor = ourColor;
    FragColor = texture(ourTexture, TexCoord) * texture(awesomeTexture, TexCoord);
}