extends Node3D
## Carrega estádio CC0 uma vez, guarda em user:// e mantém um cenário leve de reserva.

signal finished(success: bool)

const DOWNLOAD_URL := "https://www.innerscene.com/api/library/football-stadium-f7b93967/download"
const CACHE_PATH := "user://efootdls_cache/football-stadium.glb"

var scale_factor := 0.6176
var request_node: HTTPRequest
var model_loaded := false

func configure(target_scale: float) -> void:
	scale_factor = clampf(target_scale, 0.1, 1.5)

func _ready() -> void:
	if _load_cached_model():
		finished.emit(true)
		return
	_download_model()

func _load_cached_model() -> bool:
	if not FileAccess.file_exists(CACHE_PATH):
		return false
	var file := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if file == null:
		return false
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return _install_model(bytes)

func _download_model() -> void:
	request_node = HTTPRequest.new()
	request_node.name = "StadiumDownload"
	request_node.timeout = 90.0
	request_node.max_redirects = 8
	add_child(request_node)
	request_node.request_completed.connect(_on_download_completed)
	var error := request_node.request(DOWNLOAD_URL)
	if error != OK:
		finished.emit(false)

func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200 or body.size() < 100000:
		finished.emit(false)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://efootdls_cache"))
	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(body)
		file.close()
	var success := _install_model(body)
	finished.emit(success)

func _install_model(bytes: PackedByteArray) -> bool:
	if model_loaded or bytes.size() < 100000:
		return model_loaded
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_buffer(bytes, "", state)
	if error != OK:
		return false
	var imported := document.generate_scene(state) as Node3D
	if imported == null:
		return false
	imported.name = "CC0FootballStadium"
	imported.scale = Vector3.ONE * scale_factor
	imported.position = Vector3(0, -0.08, 0)
	add_child(imported)
	model_loaded = true
	return true
