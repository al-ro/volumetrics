#define GAMMA 2.2
#define INV_GAMMA (1.0/GAMMA)
#define GOLDEN_RATIO 1.61803398875

#define STEPS_PRIMARY 32
#define STEPS_LIGHT 16

in vec2 vUV;
out vec4 fragColor;

// -------------------- Uniforms -------------------- //

// RGB / FLOAT
uniform samplerCube environmentTexture;
uniform int renderBackground;

// RED / UNSIGNED_BYTE
uniform highp sampler3D densityTexture;
uniform highp sampler3D noiseTexture;

// RGBA / UNSIGNED_BYTE
uniform sampler2D blueNoiseTexture;
uniform int dithering;

uniform vec2 resolution;
uniform float time;
uniform int frame;

// scale AABB to fit the data
uniform vec3 aabbScale;
// The aspect ratio of the 3D density data
uniform vec3 dataAspect;

// Scattering coefficients
uniform vec3 sigmaS;
// Absorption coefficients
uniform vec3 sigmaA;
// Extinction coefficients, sigmaS + sigmaA
uniform vec3 sigmaT;

// [0, unbounded]
uniform float densityMultiplier;
// [0, unbounded]
uniform float detailSize;
// [0, 1]
uniform float detailStrength;

uniform vec3 sunDirection;
uniform vec3 sunColor;
// [0, unbounded]
uniform float sunStrength;

uniform float emissionStrength;

layout(std140) uniform cameraMatrices {
	mat4 viewMatrix;
	mat4 projectionMatrix;
	mat4 cameraMatrix;
};

layout(std140) uniform cameraUniforms {
	vec3 cameraPosition;
	float cameraExposure;
	float cameraFOV;
};

// -------------------- Utility functions --------------------- //

// Generate a ray for each fragment looking in the negative Z direction
vec3 rayDirection() {
	vec2 xy = gl_FragCoord.xy - 0.5 * resolution.xy;
	float z = (0.5 * resolution.y) / tan(0.5 * cameraFOV);
	return normalize(vec3(xy, -z));
}

vec3 gamma(vec3 col) {
	return pow(col, vec3(INV_GAMMA));
}

float saturate(float x) {
	return clamp(x, 0.0, 1.0);
}

// Map variable x in range [low1, high1] to be in range [low2. high2]
float remap(float x, float low1, float high1, float low2, float high2) {
	return low2 + (x - low1) * (high2 - low2) / (high1 - low1);
}

// Tonemapping
// https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
vec3 ACESFilm(vec3 x) {
	return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

// Hyperbolic curve to render a glow
// https://www.shadertoy.com/view/3s3GDn
float getGlow(float dist, float radius, float intensity) {
	return pow(radius / max(dist, 1e-6), intensity);
}

// https://www.shadertoy.com/view/4djSRW
float hash12(vec2 p) {
	p *= 129.5;
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// -------------------- AABB Intersection --------------------- //

// https://gist.github.com/DomNomNom/46bb1ce47f68d255fd5d
// Compute the near and far intersections using the slab method.
// No intersection if tNear > tFar.
vec2 intersectAABB(vec3 rayOrigin, vec3 rayDir, vec3 boxMin, vec3 boxMax) {
	vec3 tMin = (boxMin - rayOrigin) / rayDir;
	vec3 tMax = (boxMax - rayOrigin) / rayDir;
	vec3 t1 = min(tMin, tMax);
	vec3 t2 = max(tMin, tMax);
	float tNear = max(max(t1.x, t1.y), t1.z);
	float tFar = min(min(t2.x, t2.y), t2.z);
	return vec2(tNear, tFar);
}

bool insideAABB(vec3 p) {

	// Scale the default cube in [-1, 1]
	vec3 minCorner = aabbScale * vec3(-1);
	vec3 maxCorner = aabbScale * vec3(1);

	const float eps = 1e-4;
	return (p.x > minCorner.x - eps) && (p.y > minCorner.y - eps) &&
		(p.z > minCorner.z - eps) && (p.x < maxCorner.x + eps) &&
		(p.y < maxCorner.y + eps) && (p.z < maxCorner.z + eps);
}

bool getAABBIntersection(vec3 org, vec3 rayDir, out float distToStart, out float totalDistance) {

	// Scale the default cube in [-1, 1]
	vec3 minCorner = aabbScale * vec3(-1);
	vec3 maxCorner = aabbScale * vec3(1);

	// Get the intersection distances of the ray and the AABB
	vec2 intersections = intersectAABB(org, rayDir, minCorner, maxCorner);

	// If we are inside the AABB, the closest intersection is at the camera
	if(insideAABB(org)) {
		intersections.x = 1e-4;
	}

	distToStart = intersections.x;
	totalDistance = intersections.y - intersections.x;

	return intersections.x > 0.0 && (intersections.x < intersections.y);
}

// -------------------- Read Data Textures -------------------- //

float getDetailNoise(vec3 pos) {
	return texture(noiseTexture, pos).r;
}

float getDensityData(vec3 p) {
	// Correct aspect ratio of data
	p *= dataAspect;

	// Map from [-1, 1] to [0, 1]
	p = 0.5 + 0.5 * p;

	// Read the data from the red channel
	return texture(densityTexture, p).r;
}

// ------------------------ Main Code ------------------------- //

/*
*					 ,_,			|
*					(O,O)			|
*					(   )			|
*				 --"-"---dwb-
*										|
*		 YOUR CODE HERE
*/

void main() {

	// Time varying pixel color
	vec3 col = vec3(vUV, 0.5 + 0.5 * sin(time));

	// Output to render texture
	fragColor = vec4(col, 1.0);
}