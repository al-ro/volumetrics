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

	sigmaS = [1, 1, 1];
	sigmaSHandle;

	sigmaA = [0, 0, 0];
	sigmaAHandle;

	sigmaE = [1, 1, 1];
	sigmaEHandle;

	atmosphereThickness = 100e3;
	atmosphereThicknessHandle;

	planetRadius = 6371e3;
	planetRadiusHandle;

	scaleHeight = 0.085;
	scaleHeightHandle;

	scaleHeightMie = 0.012;
	scaleHeightMieHandle;

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

		this.sigmaSHandle = this.program.getOptionalUniformLocation('sigmaS');
		this.sigmaAHandle = this.program.getOptionalUniformLocation('sigmaA');
		this.sigmaEHandle = this.program.getOptionalUniformLocation('sigmaE');
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

		if (this.sigmaSHandle != null) {
			gl.uniform3fv(this.sigmaSHandle, this.sigmaS);
		}
		if (this.sigmaAHandle != null) {
			gl.uniform3fv(this.sigmaAHandle, this.sigmaA);
		}
		if (this.sigmaEHandle != null) {
			gl.uniform3fv(this.sigmaEHandle, this.sigmaE);
		}
	}

	bindUniformBlocks() {
		this.program.bindUniformBlock("cameraMatrices", UniformBufferBindPoints.CAMERA_MATRICES);
		this.program.bindUniformBlock("cameraUniforms", UniformBufferBindPoints.CAMERA_UNIFORMS);
	}
}
