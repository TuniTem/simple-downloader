extends Control


const DEFAULT_TITLE_FORMAT = "[playlist_number] [title] ([quality])"
#const DEFAULT_OUTPUT_FOLDER = "%USERPROFILE%/downloads"

const DEFAULT_WINDOWS_SIZE = Vector2i(864, 140)
const SETTINGS_WINDOWS_SIZE = Vector2i(864, 486)
const ANIMATION_SPEED : float = 0.75
const DEFAULT_OPACITY : float = 0.9

@export var selectors : Array[SingleSelectContainer]

@onready var ui_animations: AnimationPlayer = %UIAnimations
@onready var settings_animations: AnimationPlayer = %SettingsAnimations
@onready var link_entry: LineEdit = %LinkEntry
@onready var output_folder: LineEdit = %OutputFolder
@onready var title_format_edit: LineEdit = %TitleFormat
@onready var disable_animations_check: CheckBox = %DisableAnimationsCheck
@onready var audio: Button = %Audio
@onready var video: Button = %Video
@onready var mute: Button = %Mute
@onready var background: Panel = %Background
@onready var queue_completion: ProgressBar = %QueueCompletion
@onready var queue_node: MarginContainer = %Queue
@onready var download_completion: ProgressBar = %DownloadCompletion
@onready var queue_container: VBoxContainer = %QueueContainer


var first_press : bool = true
var using_audio : bool = false:
	set(val):
		mute.text = "🔊" if val else "🔈  "
		using_audio = val
		File.save_var("using_audio", using_audio)
	
var using_video : bool = false:
	set(val):
		using_video = val
		File.save_var("using_video", using_video)

var settings_open : bool = false
var output_path : String = ""
var title_format : String = DEFAULT_TITLE_FORMAT
var goin_up : bool 
var disable_animations : bool = false 

var settings : Dictionary[String, String]

func _ready() -> void:
	attempt_clipboard_link_paste()
	load_settings()
	
	YTDLP.new_hook.connect(_on_new_hook)
	YTDLP.main = self
	
	get_window().size = SETTINGS_WINDOWS_SIZE
	await get_tree().process_frame
	get_window().size = DEFAULT_WINDOWS_SIZE

func load_settings():
	using_video = File.load_var("using_video", true)
	video.button_pressed = using_video
	
	using_audio = File.load_var("using_audio", false)
	if using_video:
		audio.button_pressed = false 
		_on_video_pressed(using_audio)
		
	else:
		audio.button_pressed = using_audio
		_on_audio_pressed()
	
	output_path = File.load_var("output_path", OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS))
	output_folder.text = output_path
	
	title_format = File.load_var("title_format", DEFAULT_TITLE_FORMAT)
	title_format_edit.text = title_format
	
	disable_animations = File.load_var("disable_animations", false)
	disable_animations_check.button_pressed = disable_animations
	set_backgorund_alpha(1.0 if disable_animations else DEFAULT_OPACITY)
	
	for selector : SingleSelectContainer in selectors:
		var starting_setting : String = File.load_var(selector.update_id, selector.default_pressed_id)
		selector.update_button_state(starting_setting)
		settings[selector.update_id] = starting_setting


func attempt_clipboard_link_paste():
	var clipboard : String = DisplayServer.clipboard_get()
	if Util.is_valid_url(clipboard, true):
		link_entry.text = clipboard

func set_backgorund_alpha(to : float):
	background.get_theme_stylebox("panel").bg_color.a = to

func _on_audio_pressed() -> void:
	if video.button_pressed and audio.button_pressed and not first_press:
		ui_animations.play("audio_back", -1, 1000.0 if disable_animations else 1.0)
	
	audio.button_pressed = true
	video.button_pressed = false
	mute.button_pressed = false
	
	using_audio = true
	using_video = false
	first_press = false
	
	mute.text = "🔊"


func _on_video_pressed(set_audio : bool = true) -> void:
	if video.button_pressed and audio.button_pressed or first_press:
		ui_animations.play("audio", -1, 1000.0 if disable_animations else 1.0)
	
	audio.button_pressed = false
	video.button_pressed = true
	mute.button_pressed = false
	
	using_audio = set_audio
	using_video = true
	first_press = false


func _on_mute_pressed() -> void:
	using_audio = !using_audio

func _on_settings_pressed() -> void:
	print("s")
	var tween : Tween = create_tween()
	
	settings_open = !settings_open
	
	if not settings_open:
		tween.set_parallel()
		if goin_up and get_window().position.y > DisplayServer.screen_get_size().y- SETTINGS_WINDOWS_SIZE.y:
			tween.tween_property(get_window(), "position:y", get_window().position.y + SETTINGS_WINDOWS_SIZE.y - 140.0, ANIMATION_SPEED if not disable_animations else 0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		
		tween.tween_property(get_window(), "size", DEFAULT_WINDOWS_SIZE, ANIMATION_SPEED if not disable_animations else 0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		
		if not disable_animations:
			ui_animations.play("gear_ccw")
			settings_animations.play("hide")
		else:
			settings_animations.play("hide", -1, 1000.0)
		
		if queue_open:
			#await tween.finished
			print("SHAOWING")
			queue_container.show()
			queue_node.show()
			Util.tween(queue_container, "modulate:a", 1.0, 0.5, Tween.EASE_OUT, Tween.TRANS_CUBIC)
			await tween.finished
			set_window_vertical(DEFAULT_WINDOWS_SIZE.y + (min(MAX_QUEUE_VISIBLE_ENTRIES, YTDLP.queue.size() if prev_queue_size < YTDLP.queue.size() else YTDLP.queue.size()) + 1) * QUEUE_ADDITIONAL_HEIGHT + 10, true, 0.5)
			#update_queue_visual()
		
		
	else:
		goin_up = get_window().position.y > DisplayServer.screen_get_size().y- SETTINGS_WINDOWS_SIZE.y
		
		if goin_up: 
			tween.tween_property(get_window(), "position:y", get_window().position.y - SETTINGS_WINDOWS_SIZE.y + 140.0, ANIMATION_SPEED if not disable_animations else 0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		#if not queue_open:
		tween.tween_property(get_window(), "size", SETTINGS_WINDOWS_SIZE, ANIMATION_SPEED if not disable_animations else 0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		#else:
			#update_queue_visual()
		
		if goin_up and not disable_animations: await Util.wait(ANIMATION_SPEED)
			#tween.tween_property(get_window(), "position:y", SETTINGS_WINDOWS_SIZE.y + 80, 0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		
		
		if not disable_animations:
			ui_animations.play("gear_cw")
			settings_animations.play("show")
		else:
			settings_animations.play("show", -1, 1000.0)
		
		if queue_open:
			Util.tween(queue_container, "modulate:a", 0.0, 0.5, Tween.EASE_OUT, Tween.TRANS_CUBIC).tween_callback(queue_container.hide)
			
			
	

	#tween.tween_method(DisplayServer.window_set_size, DisplayServer.window_get_size(), SETTINGS_WINDOWS_SIZE, 0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	#get_viewport().set_si


func _on_output_folder_text_submitted(_a = null) -> void:
	var new_text : String = output_folder.text
	if DirAccess.dir_exists_absolute(new_text) and new_text != "":
		output_path = new_text
		File.save_var("output_path", new_text)
		print("New output path saved: " + new_text)
	
	else:
		output_folder.text = output_path
		print("Directory does not exist: " + new_text)

func _on_find_file_pressed() -> void:
	var output : Array = await Util.open_file_dialog(self, FileDialog.FileMode.FILE_MODE_OPEN_DIR, [], "last", "Select output folder for media")
	var selected : String = output[0]
	if selected == "": return
	
	output_folder.text = selected
	_on_output_folder_text_submitted()


func _on_title_format_reset_pressed() -> void:
	title_format_edit.text = DEFAULT_TITLE_FORMAT
	_on_title_format_text_submitted()


func _on_title_format_text_submitted(_a = null) -> void:
	var new_text : String = title_format_edit.text
	if new_text.is_valid_filename():
		title_format = new_text
		File.save_var("title_format", new_text)
		print("New title format saved: " + new_text)
	
	else:
		title_format_edit.text = title_format
		print("Invalid title format: " + new_text)

func _on_setting_selection_updated(active_button_id: String, update_id: String) -> void:
	settings[update_id] = active_button_id
	
	File.save_var(update_id, active_button_id)
	#print("saved " + update_id + " to " + active_button_id)


func _on_disable_animations_check_toggled(toggled_on: bool) -> void:
	disable_animations = toggled_on
	set_backgorund_alpha(1.0 if disable_animations else DEFAULT_OPACITY)
	File.save_var("disable_animations", disable_animations)


func _on_link_submitted(_a = null) -> void:
	var link : String = link_entry.text
	var hook : Dictionary = YTDLP.DEFAULT_PROGRESS_HOOK.duplicate()
	
	if using_video:
		#link_entry.text = ""
		var item : Callable = YTDLP.download_video(link, output_path, title_format, settings["video_format"], settings["video_quality"], not using_audio, hook)
		add_queue_item(item)
		update_queue_visual()
		#update_progress_bars(hook)
		
	elif using_audio:
		#link_entry.text = ""
		var item : Callable = YTDLP.download_audio(link, output_path, title_format, settings["audio_format"], settings["audio_quality"], hook)
		add_queue_item(item)
		update_queue_visual()
		#update_progress_bars(hook)
	
func add_queue_item(item : Callable):
	var inst = QUEUE_ENTRY.instantiate()
	
	inst.item = item
	queue_container.add_child(inst)

func _on_new_hook(hook : Dictionary, callable : Callable):
	print("b")
	print("start listen")
	await update_progress_bars(hook)
	print("stop listen")
	update_queue_visual()
	YTDLP.request_queue()

const DOWNLOAD_COMPLETION_SNAPPINESS = 2.0
func update_progress_bars(hook : Dictionary):
	download_completion.show()
	download_completion.indeterminate = true
	#var completion_tween : Tween = create_tween()
	var prev_current = -1.0
	ui_animations.play_backwards("fade_progress")
	while not hook["done"]:
		
		#print("bbb")
		#if hook["current"] == 0.0 and prev_current != 0.0:
			#print("ccc")
			#completion_tween.kill()
			#download_completion.value = -0.2
			#completion_tween = create_tween()
			#completion_tween.tween_property(download_completion, "value", 0.0, YTDLP.APPROX_INIT_TIME)
		
		queue_completion.get_parent().visible = hook["playlist"] != -1
		queue_completion.max_value = hook["playlist_total"] 
		queue_completion.value = lerpf(queue_completion.value, float(hook["playlist"] - (1)), get_process_delta_time() * DOWNLOAD_COMPLETION_SNAPPINESS)
		
		if not hook["is_audio"]:
			download_completion.value = hook["current"]
		else:
			if hook["current"] >= prev_current:
				download_completion.value = lerpf(download_completion.value, hook["current"], get_process_delta_time() * DOWNLOAD_COMPLETION_SNAPPINESS)
			else:
				download_completion.value = hook["current"]
				
		if hook["current"] != 0.0:
			download_completion.indeterminate = false
		
		prev_current = hook["current"]
		
		await get_tree().process_frame
		
	Util.tween(download_completion, "value", download_completion.max_value, 1.0, Tween.EASE_OUT, Tween.TRANS_CUBIC)
	Util.tween(queue_completion, "value", queue_completion.max_value, 1.0, Tween.EASE_OUT, Tween.TRANS_CUBIC)
	
	ui_animations.play("fade_progress", -1, 0.4)
	progress_leave()

func progress_leave():
	await ui_animations.animation_finished
	download_completion.value = 0.0
	queue_completion.value = 0.0

var queue_open : bool = false
const QUEUE_ADDITIONAL_HEIGHT : int = 26
const MAX_QUEUE_VISIBLE_ENTRIES : int = 5
const QUEUE_ENTRY = preload("uid://f81lwmrrm2w7")
var prev_queue_size : int  = -1

func update_queue_visual():
	var shown : Array[Callable] = YTDLP.queue.duplicate()
	#if YTDLP.current_request != null:
		#shown.insert(0, YTDLP.current_request)
	if shown.size() == 0:
		queue_node.hide()
	
	if shown.size() > 0 and not settings_open:
		if not queue_open:
			queue_open = true
			queue_container.show()
			queue_node.show()
			queue_container.modulate.a = 0.0
			Util.tween(queue_container, "modulate:a", 1.0, 0.5, Tween.EASE_OUT, Tween.TRANS_CUBIC)
			
		await Util.sleep(0.25)
		prev_queue_size = shown.size()
		set_window_vertical(DEFAULT_WINDOWS_SIZE.y + (min(MAX_QUEUE_VISIBLE_ENTRIES, shown.size() if prev_queue_size < shown.size() else shown.size()) + 1) * QUEUE_ADDITIONAL_HEIGHT + 10, true, 0.5)
		
	elif queue_open:
		queue_open = false
		Util.tween(queue_container, "modulate:a", 0.0, 0.5, Tween.EASE_OUT, Tween.TRANS_CUBIC).tween_callback(queue_container.hide)
		if not settings_open:
			set_window_vertical()
	
	prev_queue_size = shown.size()
		
		

func set_window_vertical(to : int = DEFAULT_WINDOWS_SIZE.y, one_motion: bool = false, speed_multiplier : float = 1.0):
	var tween : Tween = create_tween()
	if one_motion:
		tween.set_parallel()
	
	if get_window().position.y > DisplayServer.screen_get_size().y- to - 30:
		tween.tween_property(get_window(), "position:y", get_window().position.y - to + get_window().size.y - 30, ANIMATION_SPEED * speed_multiplier if not disable_animations else 0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	tween.tween_property(get_window(), "size:y", to, ANIMATION_SPEED * speed_multiplier if not disable_animations else 0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		
		

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		attempt_clipboard_link_paste()
