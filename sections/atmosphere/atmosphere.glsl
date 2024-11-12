#define GAMMA 2.2
#define INV_GAMMA (1.0/GAMMA)

#define STEPS_PRIMARY 32
#define STEPS_LIGHT 32

// "A Scalable and Production Ready Sky and Atmosphere Rendering Technique"
// With single scattering and low step count, a higher ozone coefficient look better
const vec3 rayleigh = vec3(5.802, 13.558, 33.1) * 1e-6;
const vec3 ozone = vec3(0.650, 1.881, 0.085) * 3e-6;

const vec3 sigmaS = rayleigh;
const vec3 sigmaT = rayleigh + ozone;

in vec2 vUV;
out vec4 fragColor;

uniform float planetRadius;
uniform float atmosphereRadius;

uniform float scaleHeight;

uniform vec2 resolution;
uniform float time;

uniform vec3 sunDirection;
uniform vec3 sunColor;
// [0, unbounded]
uniform float sunStrength;

// RGB / FLOAT
uniform samplerCube environmentTexture;
uniform int renderBackground;

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

// Tonemapping
// https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
vec3 ACESFilm(vec3 x) {
	return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

// Return the near and far intersections of an infinite ray and a sphere. 
// Assumes sphere at origin. No intersection if result.x > result.y
vec2 sphereIntersect(vec3 start, vec3 dir, float radius) {
	float a = dot(dir, dir);
	float b = 2.0 * dot(dir, start);
	float c = dot(start, start) - (radius * radius);
	float d = (b * b) - 4.0 * a * c;
	if(d < 0.0) {
		return vec2(1e5, -1e5);
	}
	return vec2((-b - sqrt(d)) / (2.0 * a), (-b + sqrt(d)) / (2.0 * a));
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

	// Generate a ray for the given fragment
	vec3 rayDir = rayDirection();

	// Transform the ray to point in the correct direction
	rayDir = normalize(cameraMatrix * vec4(rayDir, 0.0)).xyz;

	vec3 background = vec3(0);
	if(renderBackground > 0) {
		background = texture(environmentTexture, rayDir).rgb;
	}

	// Alignment of the view ray and light
	float cosTheta = dot(rayDir, sunDirection);

	// Draw the Sun
	background += sunStrength * sunColor * smoothstep(0.9995, 1.0, cosTheta);

	vec3 cameraPos = vec3(0.0, planetRadius + 10.0 + 15000.0 * length(cameraPosition), 0.0);

	vec2 rayPlanetIntersect = sphereIntersect(cameraPos, rayDir, planetRadius);
	bool hitsPlanet = (rayPlanetIntersect.x <= rayPlanetIntersect.y) && rayPlanetIntersect.x > 0.0;
	float dist = 0.0;

	if(hitsPlanet) {
		dist = rayPlanetIntersect.x;
		vec3 p = cameraPos + rayDir * dist;
		vec3 normal = normalize(p);

		// Draw the planet using normal colors
		background = 0.5 + 0.5 * normal;
	}

	vec3 col = background;

	// Tonemapping and gamma correction
	col = ACESFilm(cameraExposure * col);
	col = gamma(col);

	// Output to render texture
	fragColor = vec4(col, 1.0);
}