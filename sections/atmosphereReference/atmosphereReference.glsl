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

// Rayleigh phase function
float Rayleigh(float cosTheta) {
	return (3.0 / (16.0 * 3.1415926)) * (1.0 + cosTheta * cosTheta);
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

// -------------------- Atmosphere --------------------- //

float getLightRayDensity(vec3 org) {
	// Find the ray to light
	float stepL = sphereIntersect(org, sunDirection, atmosphereRadius).y / float(STEPS_LIGHT);

	// Total  optical depth for light ray
	float densityLight = 0.0;

	// Travel from sample point towards the light, stopping at where it enters the atmosphere
	for(int j = 0; j < STEPS_LIGHT; j++) {
		// Get height of point above surface
		float heightLight = max(0.0, length(org + sunDirection * float(j) * stepL) - planetRadius);

		// Add density at point to light total
		densityLight += exp(-heightLight / scaleHeight);
	}

	return densityLight * stepL;
}

// Return colour of the atmosphere or black, if the ray points to space
vec3 mainRay(vec3 cameraPos, vec3 rayDir, float cosTheta, inout vec3 totalTransmittance, float end) {

	vec3 col = vec3(0);

	vec2 rayAtmosphereIntersect = sphereIntersect(cameraPos, rayDir, atmosphereRadius);
	vec2 rayPlanetIntersect = sphereIntersect(cameraPos, rayDir, planetRadius);

	// Does the ray point into the atmosphere and the planet
	bool hitsAtmosphere = (rayAtmosphereIntersect.x <= rayAtmosphereIntersect.y) && rayAtmosphereIntersect.x > 0.0;
	bool hitsPlanet = end != 0.0;

	// Is the camera inside the atmosphere
	bool inAtmosphere = length(cameraPos) < atmosphereRadius;

	// If the ray hits the atmosphere or if the camera is in the atmosphere
	if(hitsAtmosphere || inAtmosphere) {

		// The start and end points of the ray 
		float start;

		if(inAtmosphere) {
			// In the atmosphere, the ray starts at the camera
			start = 0.0;
		} else {
			// In space, the ray starts at the near intersection with the atmosphere
			start = rayAtmosphereIntersect.x;
		}

		// The ray ends at either the near intersection with the planet or the far intersection with the atmosphere
		if(hitsPlanet) {
			end = end;
		} else {
			end = rayAtmosphereIntersect.y;
		}

		float rayLength = end - start;
		float stepS = rayLength / float(STEPS_PRIMARY);

		vec3 samplePoint = cameraPos + rayDir * start;

		vec3 radiance = vec3(0);

		float phaseFunction = Rayleigh(cosTheta);

		for(int i = 0; i < STEPS_PRIMARY; i++) {

			samplePoint += stepS * rayDir;

			// Get height of point above surface
			float height = length(samplePoint) - planetRadius;

			// Density at point
			float density = exp(-height / scaleHeight);

			// To discard contributions from points too far in the shadow of the planet,
			// test the light ray against collision with a sphere 95% of the planet size.
			// Testing with the actual planet size leads to band artifacts at sunset.
			vec2 lightRayPlanetIntersect = sphereIntersect(samplePoint, sunDirection, planetRadius * 0.95);
			bool hitsPlanetLight = (lightRayPlanetIntersect.x <= lightRayPlanetIntersect.y) && lightRayPlanetIntersect.x > 0.0;
			vec3 inscatter = vec3(0);
			if(!hitsPlanetLight) {
				inscatter = sunStrength * sunColor * exp(-sigmaT * getLightRayDensity(samplePoint));
			}

			totalTransmittance *= exp(-sigmaT * density * stepS);

			// Add inscattering for segment
			radiance += totalTransmittance * sigmaS * density * phaseFunction * inscatter * stepS;
		}

		col = radiance;
	}

	return col;
}

// -------------------- Render --------------------- //
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

		// Attenuate light arriving on the planet surface by the atmosphere
		float lightRayDensity = getLightRayDensity(p);
		vec3 transmittance = exp(-sigmaT * lightRayDensity);
		background = transmittance * sunStrength * sunColor * vec3(0.015) * clamp(dot(normal, sunDirection), 0.0, 1.0);
	}

	vec3 totalTransmittance = vec3(1.0);
	vec3 skyCol = mainRay(cameraPos, rayDir, cosTheta, totalTransmittance, dist);

	// Mix planet surface colour and atmosphere based extinction
	vec3 col = skyCol + background * totalTransmittance;

	// Tonemapping and gamma correction
	col = ACESFilm(cameraExposure * col);
	col = gamma(col);

	// Output to render texture
	fragColor = vec4(col, 1.0);
}