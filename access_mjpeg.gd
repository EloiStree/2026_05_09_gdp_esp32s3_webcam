extends Node

@export var texture_rect: TextureRect 

@export var STREAM_HOST := "192.168.137.78"
@export var STREAM_PORT := 81
@export var STREAM_PATH := "/stream?resolution=96x96"

#160×120 (QQVGA)	60–120 FPS	Very fast, great for motion tracking
#320×240 (QVGA)	30–60 FPS	Best balance for robotics / CV
#640×480 (VGA)	15–30 FPS	Good for streaming and decent detail
#800×600 (SVGA)	10–20 FPS	Starts stressing Wi-Fi and PSRAM
#1024×768+	<10 FPS	Usually too slow for “fast FPS” goals

#/stream?quality=10
#/stream?fps=15
#/stream?interval=100
#/stream?res=qvga&quality=12&fps=20
var client := HTTPClient.new()
var stream_data := PackedByteArray()
var request_sent := false
var stream_texture: ImageTexture

func _ready():
	var err = client.connect_to_host(STREAM_HOST, STREAM_PORT)

	if err != OK:
		print("Failed to connect")
		return

	set_process(true)

func _process(_delta: float) -> void:
	client.poll()

	if client.get_status() == HTTPClient.STATUS_CONNECTED and not request_sent:
		var err = client.request(
			HTTPClient.METHOD_GET,
			STREAM_PATH,
			["Accept: multipart/x-mixed-replace"]
		)

		if err != OK:
			print("Failed to request stream")
			set_process(false)
			return

		request_sent = true
		return

	if client.get_status() != HTTPClient.STATUS_BODY:
		return

	var chunk := client.read_response_body_chunk()
	while chunk.size() > 0:
		stream_data.append_array(chunk)
		_consume_mjpeg_frames()
		chunk = client.read_response_body_chunk()

func _consume_mjpeg_frames() -> void:
	while true:
		var frame_start := _find_marker(stream_data, 0xFF, 0xD8)
		if frame_start == -1:
			if stream_data.size() > 2:
				stream_data = stream_data.slice(stream_data.size() - 2)
			return

		var frame_end := _find_marker(stream_data, 0xFF, 0xD9, frame_start + 2)
		if frame_end == -1:
			if frame_start > 0:
				stream_data = stream_data.slice(frame_start)
			return

		var frame := stream_data.slice(frame_start, frame_end + 2)
		_update_texture(frame)
		stream_data = stream_data.slice(frame_end + 2)

func _find_marker(data: PackedByteArray, first: int, second: int, start: int = 0) -> int:
	for i in range(start, data.size() - 1):
		if data[i] == first and data[i + 1] == second:
			return i
	return -1

func _update_texture(frame: PackedByteArray) -> void:
	var image := Image.new()
	if image.load_jpg_from_buffer(frame) != OK:
		return

	if stream_texture == null:
		stream_texture = ImageTexture.create_from_image(image)
		texture_rect.texture = stream_texture
	else:
		stream_texture.update(image)
