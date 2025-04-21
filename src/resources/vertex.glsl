#version 330

// Input vertex attributes
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

// Input uniform values
uniform mat4 mvp;
uniform mat4 matModel;
uniform mat4 matNormal;

// Output vertex attributes (to fragment shader)
out vec3 frag_pos;
out vec2 frag_tex_coord;
out vec4 frag_color;
out vec3 frag_normal;
out vec2 uv;

void main()
{
    // Send vertex attributes to fragment shader
    frag_pos = vertexPosition;
    frag_tex_coord = vertexTexCoord;
    frag_color = vertexColor;
    frag_normal = normalize(vec3(matNormal*vec4(vertexNormal, 1.0)));

    // Calculate final vertex position
    uv = vec2(mvp*vec4(vertexPosition, 1.0));
    gl_Position = mvp*vec4(vertexPosition, 1.0);
}
