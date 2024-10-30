import { download } from "./download.js";
import { gl } from "./canvas.js";
import { createAndSetupCubemap } from "./texture.js";
import { Mesh } from "./mesh.js";
import { getScreenspaceQuad } from "./screenspace.js";
import { createAndSetupTexture } from "./texture.js";
import { CubeMapConverterMaterial } from "./materials/cubeMapConverterMaterial.js";
import { render } from "./renderCall.js";
import { RenderPass } from "./enums.js";

import { loadHDR } from "./hdrpng.js";

class Environment {
	/**
	 * Type of the file passed in.
	 *  "cubemap" | "hdr"
	 */
	type = "cubemap";

	// Internal representation is a cube map
	cubeMap;

	camera;

	updateHDR = false;

	loadFlags = [false, false, false, false, false, false];

	// [mat4, mat4, mat4]
	shUniformBuffer;
	shArray = new Float32Array(3 * 16);

	constructor(parameters) {

		let path = parameters.path;
		this.camera = parameters.camera;

		if (!path) {
			console.error("Environment must be created with a file path. Parameters: ", parameters);
		}

		this.cubeMap = createAndSetupCubemap();

		this.type = parameters.type;

		if (this.type == "cubemap") {
			this.setupCubemap(path);
		} else if (this.type == "hdr") {
			this.setHDR(path);
		} else {
			console.log("Unknown or missing environment map type: ", this.type);
		}

	}

	updateFace = function (i, obj) {
		obj.loadFlags[i] = true;
	}

	setupCubemap(path) {

		gl.activeTexture(gl.TEXTURE0);
		gl.bindTexture(gl.TEXTURE_CUBE_MAP, this.cubeMap);

		let obj = this;

		for (let i = 0; i < 6; i++) {
			const image = new Image();
			image.onload = function () {
				const target = gl.TEXTURE_CUBE_MAP_POSITIVE_X + i;

				const level = 0;
				const internalFormat = gl.RGB;
				const format = gl.RGB;
				const type = gl.UNSIGNED_BYTE;
				gl.texImage2D(target, level, internalFormat, format, type, image);

				obj.updateFace(i, obj);
			}

			gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
			gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
			gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
			gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

			image.src = path;
		}
	}

	setHDR(path) {

		download(path, "arrayBuffer").then(data => {

			if (data == null) {
				return;
			}

			let hdr = loadHDR(new Uint8Array(data));

			let texture = createAndSetupTexture();
			gl.activeTexture(gl.TEXTURE0);
			gl.bindTexture(gl.TEXTURE_2D, texture);
			gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB32F, hdr.width, hdr.height, 0, gl.RGB, gl.FLOAT, hdr.dataFloat);

			let type = hdr.width == hdr.height ? "angular" : "equirectangular";

			convertToCubeMap(texture, this.cubeMap, type);
			gl.deleteTexture(texture);

		});
	}

}

// https://www.khronos.org/opengl/wiki/Cubemap_Texture
var viewDirections = [
	[1, 0, 0],
	[-1, 0, 0],
	[0, 1, 0],
	[0, -1, 0],
	[0, 0, 1],
	[0, 0, -1]];

var upDirections = [
	[0, -1, 0],
	[0, -1, 0],
	[0, 0, 1],
	[0, 0, -1],
	[0, -1, 0],
	[0, -1, 0]];

function convertToCubeMap(sphericalTexture, cubeMap, type = "equirectangular") {

	let texture = createAndSetupTexture();

	let cubeMapConverterMaterial = new CubeMapConverterMaterial(sphericalTexture);
	cubeMapConverterMaterial.textureType = type;
	let mesh = new Mesh({ geometry: getScreenspaceQuad(), material: cubeMapConverterMaterial });
	mesh.cull = false;

	let frameBuffer = gl.createFramebuffer();

	let size = 512;
	gl.viewport(0, 0, size, size);

	gl.bindFramebuffer(gl.FRAMEBUFFER, frameBuffer);

	for (let face = 0; face < 6; face++) {

		cubeMapConverterMaterial.setCameraMatrix(m4.lookAt([0, 0, 0], viewDirections[face], upDirections[face]));

		gl.activeTexture(gl.TEXTURE0);
		gl.bindTexture(gl.TEXTURE_2D, texture);
		gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA32F, size, size, 0, gl.RGBA, gl.FLOAT, null);

		gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture, 0);

		render(RenderPass.OPAQUE, mesh);

		let target = gl.TEXTURE_CUBE_MAP_POSITIVE_X + face;

		gl.bindTexture(gl.TEXTURE_CUBE_MAP, cubeMap);
		gl.texImage2D(target, 0, gl.RGBA32F, size, size, 0, gl.RGBA, gl.FLOAT, null);
		gl.copyTexSubImage2D(target, 0, 0, 0, 0, 0, size, size);
	}

	gl.deleteFramebuffer(frameBuffer);
	gl.deleteTexture(texture);

	return cubeMap;
}

export { Environment }
