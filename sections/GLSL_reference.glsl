/*
    Selection of useful GLSL ES 3.0 types, keywords and built-in functions
    See https://registry.khronos.org/OpenGL-Refpages/es3.0/ for full spec
*/

bool boo = true;            // Test with == and negate with !boo
int i = -1;                 // Signed 32-bit integer
uint ui = 42u;              // Unsigned 32-bit integer (note the suffix u)
float f = 3.1415;           // 32-bit float. There is no double and no literal suffix 1.0f

/* 
    Note that GLSL is strictly typed and conversions are not automatic
    float f = 1;        Error: int is not float
    uint i = 1;         Error: int is not uint
    vec2(2.0, -8);      Fine: Values are converted to floats in constructor
*/

vec2 v2 = vec2(1);                  // 2-element vector of floats where both values are initialised to 1.0
vec3 v3 = vec3(v2, 17.2);           // 3-element vector [1.0, 1.0, 17.2]
vec4 v4 = vec4(v2.y, -7, v3.zy);    // 4-element vector [1.0, -7, 17.2, 1.0]

/*
    Vectors have union fields which are aliases of eachother .xyzw .rgba .stpq
    Can use .zxx to define a new vec3
    Cannot mix the three sets so .xw is illegal
    Vector elements can also be accessed using square brackets: v3[1] == v3.y == v3.g == v3.t
*/

vec3 A = vec3(1, 2, 3);
vec3 B = vec3(5, 5, 5);
vec3 C = B - A;         // Arithmetic operations are per-component and C is [4, 3, 2]

bvec2;   // a vector of two booleans
ivec3;   // a vector of three signed integers
uvec4;   // a vector of four unsigned integers

mat2 m;  // 2-by-2 matrix m.x will give the first column as a vec2. Can also use m[0]. m[0][1] gives single element.
mat3;
mat4;
mat2x3;  // Matrix of 2 columns and 3 rows

vec2 aa = m * v2;   // Matrix * Vector
vec2 bb = v2 * m;   // Transpose(Matrix) * Vector

/*
    Function which returns a float
    i is a purely local variable
    b has no guaranteed value initially but will retain value after function returns
    c has value set outside of the function and whatever is written is retained after function returns
*/
float test(uint i, out bool b, inout vec3 c) {
	b = false;
	c.x = 1.0;
	return 3.1415; // return 3; will cause an error
}

uint j = 8u;
bool k = true;
vec3 c = vec3(9, 8, 7);
float r = test(j, k, c);
// j == 8u
// k == false
// c == [1.0, 8.0, 7.0]
// r == 3.1415

vec3 a;
vec3 b;
vec3 an = normalize(a);     // a is unchanged
vec3 ab = cross(a, b);

float l = length(a - b);
float d = distance(a, b);   // same as l

uniform sampler2D tex;
uniform samplerCube cubeMap;
uniform sampler3D volume;

vec4 res = texture(tex, vec2(0.5, 1.0));            // Read texture from the middle of the bottom edge (filtering applied)
vec3 mip = texture(tex, vec2(0.5, 1.0), 2.0).aaa;   // Read the alpha channel at a specific mip-level
float green = texelFetch(tex, ivec2(12, 44), 0).g;  // Read the green channel of specified texel at a specific mip-level

vec4 env = texture(cubeMap, vec3(0.5, 1.0, 0.0));          // Cubemaps require a 3D lookup
vec4 density = texture(volume, vec3(0.5, 1.0, 0.0));       // 3D textures require a 3D lookup

float x;
float y;

sin(x);
cos(x);
tan(x);

asin(x);
acos(x);

atan(x);            // Returns a value between -π/2 to π/2.
atan(x, y);         // Returns atan of y/x between -π to π

pow(x, y);          // Raises x to the power y
exp(x);
exp2(x);
log(x);
log2(x);
sqrt(x);

abs(x);
sign(x);

floor(x);
ceil(x);

mod(x, y);

min(x, y);
max(x, y);

clamp(x, 0.0, 1.3);

mix(- 1.2, 5.3, x);
step(0.5, x);
smoothstep(6.2, 100.0, x);