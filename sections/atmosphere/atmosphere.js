import * as Renderer from "../../renderer/renderer.js"
import { AtmosphereMaterial } from "../../renderer/materials/atmosphereMaterial.js";

const gl = Renderer.gl;

// -------------------- Rendering Objects --------------------- //

let camera = new Renderer.Camera(
	Math.PI / 2.0, -2.75, 1.5, [0, 0, 0], [0, 1, 0], 60 * Math.PI / 180, gl.canvas.clientWidth / gl.canvas.clientHeight, 0.1, 100.0
);

let controls = new Renderer.Controls(camera);
controls.onWindowResize();

let environment;

let sceneTexture = Renderer.createAndSetupTexture();
gl.activeTexture(gl.TEXTURE0);
gl.bindTexture(gl.TEXTURE_2D, sceneTexture);
gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB8, 1, 1, 0, gl.RGB, gl.UNSIGNED_BYTE, null);
let sceneRenderTarget = new Renderer.RenderTarget(sceneTexture, null);

let sceneQuad = Renderer.getScreenspaceQuad();
let sceneMaterial = new Renderer.ScreenspaceMaterial(sceneTexture);
let sceneMesh = new Renderer.Mesh({ geometry: sceneQuad, material: sceneMaterial });
sceneMesh.cull = false;

let atmosphereMaterial = new AtmosphereMaterial();
let cloudMesh = new Renderer.Mesh({ geometry: sceneQuad, material: atmosphereMaterial });
cloudMesh.cull = false;

// ------------------- Time and Diagnostics ------------------- //

const stats = new Stats();
stats.showPanel(0);
stats.dom.style.cssText = "visibility: visible; position: absolute; bottom: 0px; left: 0; cursor: pointer; opacity: 0.8; z-index: 10000";
document.getElementById('canvas_overlay').appendChild(stats.dom);

let chrono = {
	time: 0.0,
	paused: false,
	lastFrame: Date.now(),
	thisFrame: Date.now(),
	frame: 0
};

let info = {
	memory: "0",
	buffers: "0",
	textures: "0",
	downloading: Renderer.getDownloadingCount(),
	primitives: "0",
	programCount: Renderer.programRepository.programs.size
};

function removeDeletedPrograms() {
	let removeKeys = [];
	Renderer.programRepository.programs.forEach((value, key) => { if (value.delete) { removeKeys.push(key); } });
	removeKeys.forEach((key) => { Renderer.programRepository.removeProgram(key); });
}

function updateMemoryStats() {
	info.memory = (Renderer.extMEM.getMemoryInfo().memory.total * 1e-6).toPrecision(4) + " MB";
	info.buffers = Renderer.extMEM.getMemoryInfo().resources.buffer;
	info.textures = Renderer.extMEM.getMemoryInfo().resources.texture;
	info.programCount = Renderer.programRepository.programs.size;
}
updateMemoryStats();

// Every 10 seconds, clean up all programs marked for deletion
setInterval(removeDeletedPrograms, 10000);
// Every 2 seconds, calculate memory stats
setInterval(updateMemoryStats, 2000);

// ---------------------- User Interface ---------------------- //

let gui = new lil.GUI({ autoPlace: false });
let customContainer = document.getElementById('canvas_overlay');
customContainer.appendChild(gui.domElement);
gui.domElement.style.cssText = "visibility: visible; position: absolute; top: 0px; right: 0; opacity: 0.8; z-index: 10000";

gui.add(controls, 'resolutionMultiplier', 0.1, 2.0, 0.1).name("Resolution multiplier").onChange(
	(v) => { controls.setMultiplier(v) }
).listen();

const infoFolder = gui.addFolder('Info');
infoFolder.add(info, 'memory').name("Memory used").disable().listen();
/*
	infoFolder.add(info, 'buffers').name("Buffers").disable().listen();
	infoFolder.add(info, 'programCount').name("Program Count").disable().listen();
	infoFolder.add(info, 'textures').name("Textures").disable().listen();
*/
infoFolder.add(info, 'downloading').name("Data downloading").disable().listen();
infoFolder.close();

let environments = new Map();
environments.set("Dikhololo Night", "../../environmentMaps/dikhololo_night_1k.hdr");
environments.set("San Giuseppe Bridge", "../../environmentMaps/san_giuseppe_bridge_1k.hdr");
environments.set("Uffizi Gallery", "../../environmentMaps/uffizi_probe_1k.hdr");
environments.set("Stars", "../../environmentMaps/starmap_2020_1k.hdr");
let environmentNames = Array.from(environments.keys());
environmentNames.sort();
let environmentController = { environment: "Stars" };

environment = new Renderer.Environment({ path: environments.get(environmentController.environment), type: "hdr", camera: camera });

const environmentFolder = gui.addFolder('Environment');
environmentFolder.add(environmentController, 'environment').name("Environment map").options(environmentNames).onChange(
	(name) => { environment.setHDR(environments.get(name)); }
);
environmentFolder.add(atmosphereMaterial, 'renderBackground').name("Render background");
environmentFolder.close();

const cameraFolder = gui.addFolder('Camera');
let fov = { value: camera.fov * 180 / Math.PI };
cameraFolder.add(fov, 'value', 10, 180, 1).name("FOV").decimals(0).listen().onChange((value) => { camera.fov = value * Math.PI / 180; });
cameraFolder.add(camera, 'exposure', 0, 2, 0.01).name("Exposure");
cameraFolder.add(camera, 'distance').name("Camera distance").decimals(2).disable().listen();
cameraFolder.close();

//gui.close();

let buttons = {
	updateMaterial: () => {
		Renderer.download("atmosphere.glsl", "text").then((shaderSource) => {
			atmosphereMaterial.program.markForDeletion();
			atmosphereMaterial.program = null;
			atmosphereMaterial.fragmentSource = shaderSource;
			cloudMesh.setMaterial(atmosphereMaterial);
		});
	},

	save: () => {
		draw();
		const link = document.createElement('a');
		link.download = 'download.png';
		link.href = gl.canvas.toDataURL();
		link.click();
		link.delete;
	},

	pause: () => {
		chrono.paused = !chrono.paused;
	}

};
buttons.updateMaterial();

gui.add(buttons, 'updateMaterial').name("Recompile");
gui.add(buttons, 'save').name("Save Image");
let playLabel = "Pause";
let pauseButton = gui.add(buttons, 'pause').name(playLabel).onChange(
	() => { playLabel = chrono.paused ? "Run" : "Pause"; pauseButton.name(playLabel); }
);
gui.add(chrono, 'time').name("Time").decimals(2).disable().listen();

const uniformFolder = gui.addFolder("Uniforms");

let sunUniforms = {
	elevation: 0.75,
	azimuth: 1.0
};

atmosphereMaterial.sunDirection = getSunDirection();

function getSunDirection() {
	let dir = [
		Math.cos(sunUniforms.azimuth) * Math.sin(sunUniforms.elevation),
		Math.cos(sunUniforms.elevation),
		Math.sin(sunUniforms.azimuth) * Math.sin(sunUniforms.elevation)
	];

	return normalize(dir);
}

uniformFolder.close();

const sunFolder = uniformFolder.addFolder("Sun");
sunFolder.add(sunUniforms, 'elevation', 0.0, Math.PI - 1e-4, 0.01).name("Elevation").onChange(
	() => { atmosphereMaterial.sunDirection = getSunDirection(); }
);
sunFolder.add(sunUniforms, 'azimuth', 0, 2.0 * Math.PI - 1e-4, 0.01).name("Azimuth").onChange(
	() => { atmosphereMaterial.sunDirection = getSunDirection(); }
);

atmosphereMaterial.sunStrength = 50.0;
sunFolder.add(atmosphereMaterial, 'sunStrength', 0, 200, 1).name("Strength");
sunFolder.addColor(atmosphereMaterial, 'sunColor').name("Color");
sunFolder.close();

const atmosphereFolder = uniformFolder.addFolder("Atmosphere");

atmosphereFolder.close();

// ------------------------ Rendering ------------------------- //

gl.clearColor(0, 0, 0, 1);
gl.depthMask(false);
gl.depthFunc(gl.ALWAYS);

function render() {
	info.downloading = Renderer.getDownloadingCount();
	if (info.downloading != 0) {
		document.getElementById('loading_spinner').style.display = "inline-block";
	} else {
		document.getElementById('loading_spinner').style.display = "none";
	}

	chrono.thisFrame = Date.now();
	let dT = (chrono.thisFrame - chrono.lastFrame) / 1000;
	if (!chrono.paused) {
		chrono.time += dT;
		// Do not let frame get too large
		chrono.frame = ++chrono.frame % 1e5;
	}
	chrono.lastFrame = chrono.thisFrame;

	cloudMesh.material.time = chrono.time;
	cloudMesh.material.frame = chrono.frame;
	cloudMesh.material.resolution = [gl.canvas.width, gl.canvas.height];

	camera.update();

	stats.begin();
	draw();
	stats.end();

	requestAnimationFrame(render);
}

function draw() {
	gl.viewport(0, 0, gl.canvas.width, gl.canvas.height);
	gl.clear(gl.COLOR_BUFFER_BIT);

	sceneRenderTarget.setSize(gl.canvas.width, gl.canvas.height);
	sceneRenderTarget.bind();

	Renderer.render(Renderer.RenderPass.TRANSMISSIVE, cloudMesh, environment);

	// Output render target color texture to screen
	gl.bindFramebuffer(gl.FRAMEBUFFER, null);
	Renderer.render(Renderer.RenderPass.OPAQUE, sceneMesh, environment);
}

render();
