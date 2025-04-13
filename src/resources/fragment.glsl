#version 330

// Input vertex attributes (from vertex shader)
in vec3 fragPosition;
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragNormal;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Output fragment color
out vec4 finalColor;

#define LIGHT_DIRECTIONAL 1
#define LIGHT_POINT       0

struct Light {
    int enabled;
    int type;
    vec3 position;
    vec3 target;
    vec4 color;
};

uniform vec4 ambient;
uniform vec3 viewPos;

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    vec3 lightDot = vec3(0.0);
    vec3 normal = normalize(fragNormal);
    vec3 viewD = normalize(viewPos - fragPosition);
    vec3 specular = vec3(0.0);

    vec4 tint = colDiffuse * fragColor;
    vec3 light = vec3(0.0);

    Light SUN = Light(
        1,
        LIGHT_DIRECTIONAL,
        vec3(100, 200, -300),
        vec3(0.0),
        vec4(1.0)
    );

    if (SUN.type == LIGHT_DIRECTIONAL) { light = -normalize(vec3(0.0) - SUN.position); }
    if (SUN.type == LIGHT_POINT      ) { light = normalize(SUN.position - fragPosition); }

    float NdotL = max(dot(normal, light), 0.0);
    lightDot += SUN.color.rgb*NdotL;

    float specCo = 0.0;
    if (NdotL > 0.0) specCo = pow(max(0.0, dot(viewD, reflect(-(light), normal))), 16.0); // 16 refers to shine
    specular += specCo;

    finalColor = (texelColor*((tint + vec4(specular, 1.0))*vec4(lightDot, 1.0)));
    finalColor += texelColor*(ambient/10.0)*tint;

    // Gamma correction
    finalColor = pow(finalColor, vec4(1.0/2.2));
}
