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
#define MAX_BOXES         1024

struct Light {
    int type;
    vec3 position;
    vec3 target;
    vec4 color;
};

uniform vec3[MAX_BOXES] boxes;
uniform vec4 ambient;
uniform vec3 viewPos;

bool rayAABB(vec3 rayOrigin, vec3 rayDir, vec3 boxMin, vec3 boxMax, out vec2 result) {
    vec3 rayInvDir = 1.0 / rayDir;
    vec3 tbot = rayInvDir * (boxMin - rayOrigin);
    vec3 ttop = rayInvDir * (boxMax - rayOrigin);
    vec3 tmin = min(ttop, tbot);
    vec3 tmax = max(ttop, tbot);
    vec2 t = max(tmin.xx, tmin.yz);
    float t0 = max(t.x, t.y);
    t = min(tmax.xx, tmax.yz);
    float t1 = min(t.x, t.y);
    result = vec2(t0, t1);
    return t1 > max(t0, 0.0);
}

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    // vec3 lightDot = vec3(0);
    // vec3 normal = normalize(fragNormal);
    // vec3 viewD = normalize(viewPos - fragPosition);

    finalColor = texelColor * colDiffuse * fragColor;

    vec3 SUN = vec3(0, 2, 0);

    vec3 ro = fragPosition;
    vec3 rd = normalize(fragPosition - SUN);
    vec2 result = vec2(0);
    for (int i = 0; i < MAX_BOXES; i += 2) {
        vec3 pos  = boxes[i + 0];
        vec3 size = boxes[i + 1];
        bool hit = rayAABB(ro, rd, pos-size/2, pos+size/2, result);
        if (hit) { finalColor.rgb *= 0.5; }
    }
}
