extends MarginContainer

@onready var animations: AnimationPlayer = %Animations
@onready var selected_label: Label = %Selected
@onready var export_info_label: Label = %ExportInfo
@onready var format_label: Label = %Format
@onready var quality_label: Label = %Quality
@onready var cancel: Button = %Cancel

var item : Callable
var selected : bool = false

var progress_hook : Dictionary
var args : Array[String]
var link : String
var output_dir : String
var format : String
var quality : String
var id : int

func _ready() -> void:
	var item_args : Array = item.get_bound_arguments()
	progress_hook = item_args[0]
	id = item_args[-1]
	args = item_args[2]
	
	
	link = args[0].remove_chars("\"")
	output_dir = args[4].remove_chars("\"")
	
	for i : int in range(args.size()):
		match args[i]:
			"--audio-format", "--recode-video":
				format = args[i + 1]
			
			"--audio-quality":
				quality = args[i+1].remove_chars("K") + "kb/s"
			
			"-f":
				if YTDLP.ARG_BINDINGS.find_key([args[i], args[i+1]]):
					quality = YTDLP.ARG_BINDINGS.find_key([args[i], args[i+1]])
				else:
					quality = "Best"
	
	
	update_selected()
	
	var truncated_link : String = link
	for header : String in ["Https://", "Http://", "www."]:
		truncated_link = truncated_link.replace(header, "")
		truncated_link = truncated_link.replace(header.to_lower(), "")
	
	
	export_info_label.text = Util.limit_string(output_dir, 28, "…", true, true) + " ➜ " + Util.limit_string(truncated_link, 24, "…", false, true)
	format_label.text = format
	quality_label.text = quality
	
	animations.play("in")

func _process(_delta: float) -> void:
	update_selected()

func update_selected():
	var prev_selected : bool = selected
	
	
	selected = item.get_bound_arguments()[-1] == YTDLP.current_request.get_bound_arguments()[-1] and not YTDLP.current_hook["done"]
	#print("\n", item)
	#print(selected, prev_selected)
	#print(YTDLP.current_request)
	#print(item)
	selected_label.text = ">" if selected else " "
	cancel.visible = !selected
	if prev_selected and not selected:
		delete()

func delete():
	animations.play("out")
	await animations.animation_finished
	queue_free()

func _on_cancel_pressed() -> void:
	for entry in YTDLP.queue:
		if entry.get_bound_arguments()[-1] == id:
			YTDLP.queue.erase(entry)
	delete()
	
