#define GAMMA 2.2
#define INV_GAMMA (1.0/GAMMA)

const int STEPS = 16;
const int STEPS_LIGHT = 16;

uniform float planetRadius;
uniform float atmosphereThickness;
uniform float atmosphereRadius;

uniform float scaleHeight;

#define PLANET_RADIUS 6371e3
#define ATMOSPHERE_THICKNESS 100e3
#define ATMOSPHERE_RADIUS float(PLANET_RADIUS + ATMOSPHERE_THICKNESS)

in vec2 vUV;
out vec4 fragColor;

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

const float SCALE_HEIGHT = float(0.08 * ATMOSPHERE_THICKNESS);

// "A Scalable and Production Ready Sky and Atmosphere Rendering Technique"
// With single scattering and low step count, a higher ozone coefficient look better
const vec3 BETA_RAYLEIGH = vec3(5.802, 13.558, 33.1) * 1e-6;
const vec3 BETA_OZONE = vec3(3.426, 8.298, 0.356) * 0.06 * 1e-5;

const vec3 SCATTERING_COEFF = BETA_RAYLEIGH;
const vec3 EXTINCTION_COEFF = BETA_RAYLEIGH + BETA_OZONE;

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

//Return the near and far intersections of an infinite ray and a sphere. 
//Assumes sphere at origin. No intersection if result.x > result.y
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

float getLightRayDensity(vec3 org, float scaleHeight) {
	//Find the ray to light
	float stepL = sphereIntersect(org, sunDirection, ATMOSPHERE_RADIUS).y / float(STEPS_LIGHT);

	//Total  optical depth for light ray
	float densityLight = 0.0;
	float dist = 0.0;

	//Travel from sample point towards the light, stopping at where it enters the atmosphere
	for(int j = 0; j < STEPS_LIGHT; j++) {

		//Get position along ray. This is the middle point of the current light segment
		vec3 samplePointLight = org + sunDirection * dist;

		//Get height of point above surface
		float heightLight = max(0.0, length(samplePointLight) - PLANET_RADIUS);

		//Add density at point to light total
		densityLight += exp(-heightLight / scaleHeight);

		dist += stepL;
	}

	return densityLight * stepL;
}

//Return colour of the atmosphere or black, if the ray points to space
vec3 mainRay(vec3 cameraPos, vec3 rayDir, float cosTheta, inout vec3 totalTransmittance, float end) {

	vec3 col = vec3(0);

	vec2 rayAtmosphereIntersect = sphereIntersect(cameraPos, rayDir, ATMOSPHERE_RADIUS);
	vec2 rayPlanetIntersect = sphereIntersect(cameraPos, rayDir, PLANET_RADIUS);  

	//Does the ray point into the atmosphere and the planet
	bool hitsAtmosphere = (rayAtmosphereIntersect.x <= rayAtmosphereIntersect.y) && rayAtmosphereIntersect.x > 0.0;
	bool hitsPlanet = end != 0.0;

	//Is the camera inside the atmosphere
	bool inAtmosphere = length(cameraPos) < ATMOSPHERE_RADIUS;

	//If the ray hits the atmosphere or if the camera is in the atmosphere
	if(hitsAtmosphere || inAtmosphere) {

		//The start and end points of the ray 
		float start;

		if(inAtmosphere) {
			//In the atmosphere, the ray starts at the camera
			start = 0.0;
		} else {
			//In space, the ray starts at the near intersection with the atmosphere 
			start = rayAtmosphereIntersect.x;
		}

		//The ray ends at either the near intersection with the planet or the far intersection with the atmosphere
		if(hitsPlanet) {
			end = end;
		} else {
			end = rayAtmosphereIntersect.y;
		}

		float rayLength = end - start;
		float stepS = rayLength / float(STEPS);

		vec3 samplePoint = cameraPos + rayDir * start;

		vec3 radiance = vec3(0);

		// Rayleigh phase function
		float phase = 0.05968310365 * (1.0 + cosTheta * cosTheta);

		for(int i = 0; i < STEPS; i++) {

			samplePoint += stepS * rayDir;

			//Get height of point above surface
			float height = length(samplePoint) - PLANET_RADIUS;

			//Density at point
			float density = exp(-height / SCALE_HEIGHT);

			//To discard contributions from points too far in the shadow of the planet,
			//test the light ray against collision with a sphere 95% of the planet size.
			//Testing with the actual planet size leads to band artifacts at sunset.
			vec2 lightRayPlanetIntersect = sphereIntersect(samplePoint, sunDirection, PLANET_RADIUS * 0.95);
			bool hitsPlanetLight = (lightRayPlanetIntersect.x <= lightRayPlanetIntersect.y) && lightRayPlanetIntersect.x > 0.0;
			vec3 inscatter = vec3(0);
			if(!hitsPlanetLight) {
				inscatter = exp(-EXTINCTION_COEFF * getLightRayDensity(samplePoint, SCALE_HEIGHT));
			}

			totalTransmittance *= exp(-EXTINCTION_COEFF * density * stepS);

			// Add inscattering for segment
			radiance += totalTransmittance * sunStrength * sunColor * phase * SCATTERING_COEFF * density * inscatter * stepS;
		}

		col = radiance;
	}

	return col;
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

	// Add a glow to visualize the light source
	background += sunStrength * sunColor * smoothstep(0.9995, 1.0, (0.5 + 0.5 * cosTheta));

	vec3 cameraPos = vec3(0.0, PLANET_RADIUS + 10.0 + 15000.0 * length(cameraPosition), 0.0);

	vec2 rayPlanetIntersect = sphereIntersect(cameraPos, rayDir, PLANET_RADIUS);
	bool hitsPlanet = (rayPlanetIntersect.x <= rayPlanetIntersect.y) && rayPlanetIntersect.x > 0.0;
	float dist = 0.0;

	if(hitsPlanet) {
		dist = rayPlanetIntersect.x;
		vec3 p = cameraPos + rayDir * dist;
		vec3 normal = normalize(p);

		background = 0.5 + 0.5 * normal;
	}

	vec3 col = background;

	// Tonemapping and gamma correction
	col = ACESFilm(cameraExposure * col);
	col = gamma(col);

	// Output to render texture
	fragColor = vec4(col, 1.0);
}