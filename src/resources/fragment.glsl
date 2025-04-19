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
#define MAX_BOXES         4096

struct Light {
    int type;
    vec3 position;
    vec3 target;
    vec4 color;
};

uniform vec3[MAX_BOXES] boxes;
uniform vec4 ambient;
uniform vec3 viewPos;

vec2 boxIntersection( in vec3 ro, in vec3 rd, vec3 boxSize, out vec3 outNormal ) {
    vec3 m = 1.0/rd; // can precompute if traversing a set of aligned boxes
    vec3 n = m*ro;   // can precompute if traversing a set of aligned boxes
    vec3 k = abs(m)*boxSize;
    vec3 t1 = -n - k;
    vec3 t2 = -n + k;
    float tN = max( max( t1.x, t1.y ), t1.z );
    float tF = min( min( t2.x, t2.y ), t2.z );
    if( tN>tF || tF<0.0) return vec2(-1.0); // no intersection
    outNormal = (tN>0.0) ? step(vec3(tN),t1) : // ro ouside the box
                           step(t2,vec3(tF));  // ro inside the box
    outNormal *= -sign(rd);
    return vec2( tN, tF );
}

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    // vec3 lightDot = vec3(0);
    // vec3 normal = normalize(fragNormal);
    vec3 viewD = normalize(viewPos - fragPosition);

    // finalColor = vec4(fragPosition.rgb, 1.0);

    finalColor = fragColor;
    vec4 shadow_color = fragColor * 0.5;

    vec3 SUN = vec3(1, 2, -1) * 100;

    vec3 ro = fragPosition;
    vec3 rd = -normalize(0 - SUN);
    vec3 normal = vec3(0);
    for (int i = 0; i < MAX_BOXES; i += 2) {
        vec3 pos  = boxes[i + 0];
        if (pos.x == 0.0 && pos.y == 0.0 && pos.z == 0.0) break;
        vec3 size = boxes[i + 1]/2;
        vec2 result = boxIntersection(ro - pos, rd, size, normal);
        if (result.x != -1.0 && result.y != -1.0) { finalColor = shadow_color; }
    }
}
