#version 330

// Input vertex attributes (from vertex shader)
in vec3 frag_pos;
in vec2 frag_tex_coord;
in vec4 frag_color;
in vec3 frag_normal;
in vec2 uv;

// Input uniform values
uniform sampler2D texture0;

// Output fragment color
out vec4 final_color;

#define MAX_BOXES 1024
#define EPSILON   0.0000001

uniform float time;
uniform vec3[MAX_BOXES] boxes;
uniform int num_boxes;
uniform vec3 viewPos;
uniform vec3 bg_color_1;
uniform vec3 bg_color_2;
uniform int render_state; // 0 = nothing ; 1 = flat color ; 2 = shadows ; 4 = background

bool intersectRayAABB(vec3 rayOrig, vec3 rayDir, vec3 boxMin, vec3 boxMax, out float tNear, out float tFar) {
    // Avoid division‑by‑zero by pushing zero components a little
    vec3 invDir = 1.0 / max(abs(rayDir), vec3(1e-20)) * sign(rayDir);

    vec3 t0 = (boxMin - rayOrig) * invDir;
    vec3 t1 = (boxMax - rayOrig) * invDir;

    vec3 tMin = min(t0, t1);
    vec3 tMax = max(t0, t1);

    tNear = max(max(tMin.x, tMin.y), tMin.z);
    tFar  = min(min(tMax.x, tMax.y), tMax.z);

    // Hit if intervals overlap and the box is in front of us
    return tFar >= max(tNear, 0.0);
}

bool equal( in vec2 a, in vec2 b ) {
    return abs(a.x - b.x) <= EPSILON &&
    abs(a.y - b.y) <= EPSILON;
}
bool equal( in vec3 a, in vec3 b ) {
    return abs(a.x - b.x) <= EPSILON &&
    abs(a.y - b.y) <= EPSILON &&
    abs(a.z - b.z) <= EPSILON;
}

float noise(vec3 p) {
    return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

float hash(vec3 p) {
    p = 50.0*fract(p*0.3183099 + vec3(0.71,0.113,0.419));
    return -1.0+2.0*fract(p.x*p.y*p.z*(p.x+p.y+p.z));
}

// return value noise (in x) and its derivatives (in yzw)
vec4 noised(in vec3 x) {
    vec3 i = floor(x);
    vec3 w = fract(x);

    vec3 u = w*w*w*(w*(w*6.0-15.0)+10.0);
    vec3 du = 30.0*w*w*(w*(w-2.0)+1.0);

    float a = hash(i+vec3(0,0,0));
    float b = hash(i+vec3(1,0,0));
    float c = hash(i+vec3(0,1,0));
    float d = hash(i+vec3(1,1,0));
    float e = hash(i+vec3(0,0,1));
    float f = hash(i+vec3(1,0,1));
    float g = hash(i+vec3(0,1,1));
    float h = hash(i+vec3(1,1,1));

    float k0 =   a;
    float k1 =   b - a;
    float k2 =   c - a;
    float k3 =   e - a;
    float k4 =   a - b - c + d;
    float k5 =   a - c - e + g;
    float k6 =   a - b - e + f;
    float k7 = - a + b + c - d + e - f - g + h;

    return vec4( k0 + k1*u.x + k2*u.y + k3*u.z + k4*u.x*u.y + k5*u.y*u.z + k6*u.z*u.x + k7*u.x*u.y*u.z,
                du * vec3( k1 + k4*u.y + k6*u.z + k7*u.y*u.z,
                          k2 + k5*u.z + k4*u.x + k7*u.z*u.x,
                          k3 + k6*u.x + k5*u.y + k7*u.x*u.y ) );
}

vec4 fbmd(in vec3 x) {
    const float scale  = 1.5;

    float a = 0.0;
    float b = 0.5;
    float f = 1.0;
    vec3  d = vec3(0.0);
    for( int i=0; i<8; i++ )
    {
        vec4 n = noised(f*x*scale);
        a += b*n.x;           // accumulate values
        d += b*n.yzw*f*scale; // accumulate derivatives
        b *= 0.5;             // amplitude decrease
        f *= 2.0;             // frequency increase
    }

    return vec4( a, d );
}

vec4 fbm_warp(in vec3 p) {
    // return fbmd(p + time / 100.0);
    // return fbmd(p + fbmd(p + time / 100.0).x);
    return fbmd(p + fbmd(p + fbmd(p + time / 100.0).x).x);
}

float length_sq(in vec3 v) { return v.x*v.x + v.y*v.y + v.z*v.z; }
float length_sq(in vec2 v) { return v.x*v.x + v.y*v.y; }

void main() {
    vec4 texelColor = texture(texture0, frag_tex_coord);
    vec3 viewD = normalize(viewPos - frag_pos);
    vec3 color = frag_color.rgb;
    vec3 shadow_color = frag_color.rgb * 0.25;

    if (render_state == 0) {
        return;
    }
    if ((render_state & 1) == 1) {
        // flat color
        final_color = frag_color;
    }
    if ((render_state & 2) == 2) {
        // shadows
        if (length_sq(frag_pos) < 20*20) {
            vec3 SUN = vec3(1, 3, -2) * 100;
            vec3 rd = normalize(SUN);
            vec3 ro = frag_pos;// + frag_normal * EPSILON;
            // for (int i = 0; i < num_boxes; i += 2) {
            int x = int(floor(frag_pos.x));
            int y = int(floor(frag_pos.z));
            vec3 pos  = boxes[2 * (x + y * 12) + 0];
            vec3 size = boxes[2 * (x + y * 12) + 1];

            if (abs(size.x) > EPSILON) {
                float tN, tF;
                if (intersectRayAABB(ro, rd, pos - size/2, pos + size/2, tN, tF)) {
                    if (tF > EPSILON) {
                        color = mix(color, shadow_color, 1.0 - sqrt(tN / tF));
                    }
                }
            } else {
                // color = vec3(1,0,1);
            }
            // }
            color.rgb = clamp(color.rgb, frag_color.rgb * 0.1, frag_color.rgb * 2.0);
        }
    }
    if ((render_state & 4) == 4) {
        // background
        if (length_sq(frag_pos) >= 20*20) {
            vec2 p = uv * 10;
            // p -= mod(p, 0.1);
            vec4 n = fbm_warp(vec3(p + 1000.0, 0) * 0.1);
            float r = n.x;// * clamp(length(n.yzw) - mod(length(n.yzw), 1.0), 0.1, 1.0);
            vec3 c1 = bg_color_1; //vec3(0.392, 0.454, 0.545); //vec3(0.341, 0.396, 0.478);
            vec3 c2 = bg_color_2; //vec3(0.850, 0.466, 0.023); //vec3(0.956, 0.533, 0.023);
            color = (max(r, 0.0) * c1 + max(-r, 0.0) * c2);// * pow(length(n.yzw), 0.5);
        }
    }

    final_color = vec4(color, 1.0);
}
