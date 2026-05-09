# CameraStream.gd
extends Node

@export var stream_url: String = "http://192.168.137.78/capture"  # or /stream for MJPEG
@export var texture_rect: TextureRect

var http_request: HTTPRequest
var image: Image
var texture: ImageTexture

func _ready():
	image = Image.new()
	texture = ImageTexture.new()
	if texture_rect:
		texture_rect.texture = texture
	
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_frame_received)
	
	fetch_next_frame()

func fetch_next_frame():
	# For MJPEG stream endpoint you may need to handle multipart, but many people just poll /capture
	var err = http_request.request(stream_url)  # or a single JPEG endpoint if available
	if err != OK:
		print("Request failed: ", err)
		await get_tree().create_timer(0.5).timeout
		fetch_next_frame()
		return

func _on_frame_received(result, response_code, headers, body):
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var err = image.load_jpg_from_buffer(body)
		if err == OK:
			texture.set_image(image)   # or texture.update(image) for better perf
			if texture_rect:
				texture_rect.texture = texture  # ensure it refreshes
		else:
			print("Failed to load JPEG: ", err)
	else:
		print("HTTP error - Result: ", result, " Code: ", response_code)
	
	# Fetch next frame (adjust rate as needed)
	await get_tree().create_timer(0.05).timeout  # ~20 FPS max
	fetch_next_frame()
