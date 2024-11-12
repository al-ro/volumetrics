import { gl, Material, UniformBufferBindPoints } from '../renderer.js'

export class AtmosphereMaterial extends Material {

	timestamped = true;
	needsEnvironmentTexture = true;
	textureUnits = 0;

	resolution = [1, 1];
	resolutionHandle;
	time = 0;
	timeHandle;

	hasTransmission = true;

	environmentTexture;
	environmentTextureHandle;
	environmentTextureUnit;

	sunStrength = 100.0;
	sunStrengthHandle;

	sunColor = [1, 1, 1];
	sunColorHandle;

	sunDirection = normalize([0.0, 1.0, 0.5]);
	sunDirectionHandle;

	renderBackground = true;
	renderBackgroundHandle;

	atmosphereThickness = 100e3;
	atmosphereThicknessHandle;

	planetRadius = 6371e3;
	planetRadiusHandle;

	atmosphereRadiusHandle;

	scaleHeight = 0.085;
	scaleHeightHandle;

	fragmentSource = /*glsl*/`
    uniform float time;

    layout(std140) uniform cameraMatrices{
      mat4 viewMatrix;
      mat4 projectionMatrix;
      mat4 cameraMatrix;
    };

    layout(std140) uniform cameraUniforms{
      vec3 cameraPosition;
      float cameraExposure;
      float cameraFOV;
    };

    in vec2 vUV;
    out vec4 fragColor;

    void main(){
      fragColor = vec4(vUV, 0.5 + 0.5 * sin(time), 1.0);
    }
    `;

	constructor() {

		super();

		this.attributes = ["POSITION", "TEXCOORD_0"];

		this.textureUnits = 0;

		this.environmentTextureUnit = this.textureUnits++;
	}

	getVertexShaderSource() {
		return /*glsl*/`
      in vec3 POSITION;
      in vec2 TEXCOORD_0;
    
      out vec2 vUV;
    
      void main(){
        vUV = TEXCOORD_0;
        vUV.y = 1.0 - vUV.y;
        gl_Position = vec4(POSITION, 1.0);
      }
    `;
	}

	getFragmentShaderSource() {
		return this.fragmentSource;
	}

	getUniformHandles() {
		this.timeHandle = this.program.getOptionalUniformLocation('time');
		this.resolutionHandle = this.program.getOptionalUniformLocation('resolution');

		this.environmentTextureHandle = this.program.getOptionalUniformLocation('environmentTexture');
		this.renderBackgroundHandle = this.program.getOptionalUniformLocation('renderBackground');

		this.sunDirectionHandle = this.program.getOptionalUniformLocation('sunDirection');
		this.sunColorHandle = this.program.getOptionalUniformLocation('sunColor');
		this.sunStrengthHandle = this.program.getOptionalUniformLocation('sunStrength');

		this.scaleHeightHandle = this.program.getOptionalUniformLocation('scaleHeight');
		this.atmosphereRadiusHandle = this.program.getOptionalUniformLocation('atmosphereRadius');
		this.planetRadiusHandle = this.program.getOptionalUniformLocation('planetRadius');
	}

	bindUniforms() {
		gl.uniform1f(this.timeHandle, this.time);
		gl.uniform2fv(this.resolutionHandle, this.resolution);

		if (this.environmentTextureHandle != null) {
			gl.activeTexture(gl.TEXTURE0 + this.environmentTextureUnit);
			gl.bindTexture(gl.TEXTURE_CUBE_MAP, this.environmentTexture);
			gl.uniform1i(this.environmentTextureHandle, this.environmentTextureUnit);
		}

		if (this.renderBackgroundHandle != null) {
			gl.uniform1i(this.renderBackgroundHandle, this.renderBackground ? 1 : 0);
		}

		if (this.sunDirectionHandle != null) {
			gl.uniform3fv(this.sunDirectionHandle, this.sunDirection);
		}
		if (this.sunStrengthHandle != null) {
			gl.uniform1f(this.sunStrengthHandle, this.sunStrength);
		}
		if (this.sunColorHandle != null) {
			gl.uniform3fv(this.sunColorHandle, this.sunColor);
		}

		if (this.scaleHeightHandle != null) {
			gl.uniform1f(this.scaleHeightHandle, this.scaleHeight * this.atmosphereThickness);
		}
		if (this.planetRadiusHandle != null) {
			gl.uniform1f(this.planetRadiusHandle, this.planetRadius);
		}
		if (this.atmosphereRadiusHandle != null) {
			gl.uniform1f(this.atmosphereRadiusHandle, this.planetRadius + this.atmosphereThickness);
		}
	}

	bindUniformBlocks() {
		this.program.bindUniformBlock("cameraMatrices", UniformBufferBindPoints.CAMERA_MATRICES);
		this.program.bindUniformBlock("cameraUniforms", UniformBufferBindPoints.CAMERA_UNIFORMS);
	}
}
