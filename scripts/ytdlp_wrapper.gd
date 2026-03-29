extends Node
var main : Control # cannonically this hsouldnt be here
enum Binary {
	YTDLP,
	FFMPEG,
	FFPROBE
}

const ARG_BINDINGS : Dictionary[String, Array] = {
	# audio format args
	"mp3": ["--extract-audio", "--audio-format", "mp3"],
	"wav" : ["--extract-audio", "--audio-format", "wav"],
	"ogg" : ["--extract-audio", "--audio-format", "vorbis"],
	"flac" : ["--extract-audio", "--audio-format", "flac"],
	"audio_original" : [],
	
	# audio quality args
	"320kbps" : ["--audio-quality", "320K"],
	"256kbps" : ["--audio-quality", "256K"],
	"128kbps" : ["--audio-quality", "128K"],
	"96kbps" : ["--audio-quality", "96K"],
	"64kbps" : ["--audio-quality", "64K"],
	"8kbps" : ["--audio-quality", "8K"],
	
	## video codec args
	#"h264" : ["--codec", "video:h264,audio:aac"],
	#"av1" : ["--codec", "video:av1,audio:aac"],
	#"vp9" : ["--codec", "video:vp9,audio:opus"],
	#"uncompressed" : [],
	
	# video format args
	"mp4" : ["--recode-video", "mp4"],
	"mkv" : ["--recode-video", "mkv"],
	"avi" : ["--recode-video", "avi"],
	"webm" : ["--recode-video", "webm"],
	"video_original" : [],
	
	# video quality args
	"max" : ["-f", "\"bestvideo+bestaudio/best\""],
	"4k" : ["-f", "\"bestvideo[height<=2160]+bestaudio/best[height<=2160]/best\""],
	"1440p" : ["-f","\"bestvideo[height<=1440]+bestaudio/best[height<=1440]/best\"" ],
	"1080p" : ["-f", "\"bestvideo[height<=1080]+bestaudio/best[height<=1080]/best\""],
	"720p" : ["-f", "\"bestvideo[height<=720]+bestaudio/best[height<=720]/best\""],
	"480p" : ["-f", "\"bestvideo[height<=480]+bestaudio/best[height<=480]/best\""],
	"360p" : ["-f", "\"bestvideo[height<=360]+bestaudio/best[height<=360]/best\""],
	"240p" : ["-f", "\"bestvideo[height<=240]+bestaudio/best[height<=240]/best\""],
	"144p" : ["-f", "\"bestvideo[height<=144]+bestaudio/best[height<=144]/best\""],
	
	# util
	"has_playlist" : ["--flat-playlist", "--print", "\"%(playlist_title)s\"", "--no-download", "--no-playlist"]
}

const TITLE_COUNT_DELIMIATOR : String = "<[@$%!!!4>"

const FILE_CHARACTER_REPLACEMENT : Dictionary[String, String] = {
	":" : "：",
	"/" : "／",
	"\\" : "",
	"?" : "？",
	"*" : "＊",
	"\"" : "＼",
	"|" : "｜",
	"%" : "％",
	"<" : "＜",
	">" : "＞"
}

#const CONTAINER_BINDINGS : Dictionary[String, String] = {
	#"mp4" : "h264",
	#"avi" : 
#}


const BINARY_NAMES : Dictionary[Binary, String] = {
	Binary.YTDLP : "yt-dlp.exe",
	Binary.FFMPEG : "ffmpeg.exe",
	Binary.FFPROBE : "ffprobe.exe" 
}

const ZIP_NAMES : Dictionary[Binary, String] = {
	Binary.YTDLP : "yt-dlp.zip",
	Binary.FFMPEG : "ffmpeg.zip",
	Binary.FFPROBE : "ffprobe.zip" 
}

const FILENAME_FORMAT_FLAGS : Dictionary[String, String] = {
	"[playlist_number]" : "%(playlist_autonumber|)s",
	"[title]" : "%(title)s",
	"[author]" : "%(creator|Unknown)s",
	#"[quality]" : "%(asr)s",
	#"[quality]" : "%(height)sp"
}

const ZIPS_LOCATION : String = "res://bin/"
const BINARY_LOCATION : String = "user://bin/"

const FIND_DEFAULT_BROWSER_COMMAND : String = "powershell -command \"(Get-ItemProperty 'HKCU:\\Software\\Microsoft\\Windows\\Shell\\Associations\\UrlAssociations\\http\\UserChoice').ProgId\""
const BROWSER_NORMALIZATOR9000 : Dictionary[String, String] = {
	"ChromeHTML": "chrome",
	"FirefoxURL": "firefox",
	"MSEdgeHTM": "edge",
	"BraveHTML": "brave",
	"OperaStable": "opera",
	"VivaldiHTM": "vivaldi",
	"NaverWale": "whale",
	"WhaleHTML": "whale",
}

const MAX_DOWNLOAD_TRANSCODE_RATIO_HISTORY : int = 8
const APPROX_INIT_TIME = 4.0

signal new_hook(hook : Dictionary, callable : Callable)

var web_browser : String = ""
var download_transcode_ratio_history : Array[float] = [0.018]
var download_transcode_ratio : float:
	get():
		var total : float = 0.0
		for ratio : float in download_transcode_ratio_history:
			total += ratio
		
		return total / download_transcode_ratio_history.size()

var child_processes_ids : Array[int] = []

var queue : Array[Callable]
var current_request : Callable

func _ready() -> void:
	unhandled_error.connect(_on_unhandled_error)
	
	# find default web browser
	var output = []
	OS.execute("CMD.exe", ["/C", FIND_DEFAULT_BROWSER_COMMAND], output)
	for browser_prog_id : String in BROWSER_NORMALIZATOR9000.keys():
		if output[0].begins_with(browser_prog_id):
			web_browser = BROWSER_NORMALIZATOR9000[browser_prog_id]
	
	if web_browser == "": # uh oh!
		printerr("Web browser could not be found: " + str(output[0]))
		web_browser = "chromium"#? ?? ?!? 
	
	print("Default browser: " + web_browser)
	
	# make sure all the bianaries exist
	File.verify_dir(BINARY_LOCATION)
	for key in ZIP_NAMES.keys():
		var zip_location : String = ZIPS_LOCATION + ZIP_NAMES[key]
		var bin_location : String = BINARY_LOCATION + BINARY_NAMES[key]
		
		assert(FileAccess.file_exists(zip_location))
		if not FileAccess.file_exists(bin_location):
			File.extract_all_from_zip(zip_location, BINARY_LOCATION, false)
			print("Created " + BINARY_NAMES[key] + " at " + ProjectSettings.globalize_path(bin_location))
	
	await update_ytdlp()
	
	# load save data
	download_transcode_ratio_history = File.load_var("download_transcode_ratio_history", download_transcode_ratio_history)



func run(args : Array, binary : Binary = Binary.YTDLP, console : bool = false, print_output : bool = false, block : bool = true, print_input : bool = false):
	var concatinated_args : String = ""
	for arg : String in args:
		concatinated_args += " " + arg
	
	if print_input:
		print("RUNNING COMMAND:\ncd " + ProjectSettings.globalize_path(BINARY_LOCATION) + " && start \"\" /belownormal /b /wait " + BINARY_NAMES[binary] + concatinated_args)
	
	var output : Array = []
	
	if block : 
		OS.execute("CMD.exe", ["/C", "cd " + ProjectSettings.globalize_path(BINARY_LOCATION) + " && start \"\" /belownormal /b /wait " + BINARY_NAMES[binary] + concatinated_args], output, false, console)
		if print_output:
			print(output[0])
		return output
		
	else:
		var pipe : Dictionary = OS.execute_with_pipe("CMD.exe", ["/C", "cd " + ProjectSettings.globalize_path(BINARY_LOCATION) + " && start \"\" /belownormal /b /wait " + BINARY_NAMES[binary] + concatinated_args], false)
		child_processes_ids.append(pipe["pid"])
		return pipe
	

	

func update_ytdlp():
	print ("Verifying YT-DLP version...")
	run(["--update"], Binary.YTDLP, false, true)

func format_filename(format_string : String):
	var result : String = format_string
	for key in FILENAME_FORMAT_FLAGS.keys():
		result = result.replace(key, FILENAME_FORMAT_FLAGS[key])
	
	return result

const SET_PROGRESS_IGNORE_AMMOUNT = [0, 60]
var current_set_progress_timer : int = 1

func _set_progress(to : float, progress_hook : Dictionary):
	#current_set_progress_timer -= 1
	#print("tuahweening")
	#if current_set_progress_timer == 0:
	#print("hawkweening")
	progress_hook["current"] = to
	current_set_progress_timer = Util.randi_array(SET_PROGRESS_IGNORE_AMMOUNT)

func update_progress(process_hook : Dictionary, progress_hook : Dictionary, using_audio : bool):
	var io : FileAccess = process_hook["stdio"]
	var err : FileAccess = process_hook["stderr"]
	var process_id : int = process_hook["pid"]
	var is_playlist : bool = false
	var time_start : float = Util.TIME
	var download_time : float = 0.0
	var transcode_time : float = 0.0
	var transcode_flag : bool = false
	var finished_flag : bool = false
	
	while OS.is_process_running(process_id):
		await get_tree().process_frame
		#if Util.run_every(10, self):
			#print(progress_hook["current"])
		
		var output : String = io.get_as_text().remove_chars("\n\r")
		var errors : String = err.get_as_text()
		if output.length() > 3:
			if output.contains("[download]"):
				var last_percent : int = output.rfind("% of ")
				#print("a " + str(last_percent))
				if output.contains("d] Desti"):
					time_start = Util.TIME
					progress_hook["current"] = 0.0
					
				
				if output.contains("100.0% of") and not finished_flag:
					finished_flag = true
					download_time = Util.TIME - time_start
					#print("detected finish! ", download_time)
					
					if not using_audio:
						var predicted_transcode_time : float = download_time / download_transcode_ratio
						var tween : Tween = create_tween()
						tween.tween_method(_set_progress.bind(progress_hook), progress_hook["current"], 1.0, predicted_transcode_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
						progress_hook["tween"] = tween
					
					else:
						progress_hook["current"] = 1.0
						
					
					
				elif last_percent != -1 and not finished_flag:
					#print("b!!")
					var split : PackedStringArray = output.split(" ")
					#print(split)
					for i : int in range(0, split.size() - 1):
						#print("split: ", split[i], " and ", split[i+1])
						if split[i].contains("%") and split[i+1] == "of":
							progress_hook["current"] = float(split[i].remove_chars("%")) / 100.0 * (download_transcode_ratio if not using_audio else 1.0)
							#print("c!!", progress_hook["current"])
							break
					
					
					
				elif output.find("] Playlist "):
					is_playlist = not output.contains(" items of 1")
				
				if is_playlist and output.contains("] Downloading item "):
					var split : PackedStringArray = output.split(" ")
					for i : int in range(split.size()):
						if split[i] == "Downloading" and split[i+1] == "item" and split[i+3] == "of":
							progress_hook["playlist_total"] = int(split[i+4])
							progress_hook["playlist"] = int(split[i+2])
							finished_flag = false
							progress_hook["current"] = 0.0
							break
			
			if not using_audio:
				if not transcode_flag and output.contains("[VideoConvertor] Converting video from"):
					transcode_flag = true
				
				elif transcode_flag and output.contains("Deleting original file"):
					transcode_flag = false
					
					transcode_time = Util.TIME - time_start - download_time
					#print("download_time ", download_time, " transcode_time ", transcode_time)
					if progress_hook.has("tween") and progress_hook["tween"]:
						progress_hook["tween"].kill()
					
					var ratio : float = download_time / transcode_time
					if ratio < 0.1:
						download_transcode_ratio_history.append(ratio)
					
					if download_transcode_ratio_history.size() > MAX_DOWNLOAD_TRANSCODE_RATIO_HISTORY:
						download_transcode_ratio_history.pop_front()
					
					File.save_var("download_transcode_ratio_history", download_transcode_ratio_history)
					
				
				
			
			print(output)
		
		if errors.length() > 3:
			send_error(errors)
	
	progress_hook["done"] = true

signal unhandled_error(code : int, message : String)
signal user_error(code : int, message : String)

const USER_ERRORS : Dictionary[String, Array] = {
	"is not a valid URL": [2, "Invalid URL"],
	"No media found": [3, "No media found"],
	"Unsupported URL": [4, "Unsupported URL"]
}

const PROGRAM_ERRORS : Dictionary[String, Array] = {
	"no such option": [101, "Argument parse error"],
	"Failed to extract any player response" : [102, "Timed out - No player response"],
	"being used by another process" : [103, "Attempted to access file in use"]
} 
const IGNORE_ERRORS : Array = [
	"WARNING",
	"yt-dlp.exe [OPTIONS] URL",
	"Unicode parsing error"
]

func send_error(errors_str : String): 
	var errors : PackedStringArray = errors_str.split("\n")
	for error : String in errors:
		if error.length() < 3:
			continue
		
		printerr(error)
		
		for ignore_error in IGNORE_ERRORS:
			if error.contains(ignore_error):
				print("misc unhandled error above")
				continue
		
		var handled : bool = false
		for user_err in USER_ERRORS.keys():
			if error.contains(user_err):
				user_error.emit(USER_ERRORS[user_err][0], USER_ERRORS[user_err][1])
				handled = true
		
		for program_err in PROGRAM_ERRORS.keys():
			if error.contains(program_err):
				unhandled_error.emit(PROGRAM_ERRORS[program_err][0], PROGRAM_ERRORS[program_err][1])
				handled = true
		
		if not handled:
			unhandled_error.emit(201, error.right(-error.find("]") + 2))


func _on_unhandled_error(code : int, message : String):
	print("!! Important Error Above !!")

const DEFAULT_PROGRESS_HOOK : Dictionary = {"current": 0.0, "playlist": -1, "playlist_total" : -1, "is_audio" : false, "done" : false}

func download_audio(link : String, output_dir : String, file_name_format: String, format : String, quality : String, progress_hook : Dictionary = DEFAULT_PROGRESS_HOOK.duplicate()):
	var args : Array[String] = [
		"\"" + link + "\"",
		"-o", "\"" + format_filename(file_name_format).replace("[quality]", quality) + ".%(ext)s" + "\"",
		"-P", "\"" + output_dir + "/" + await get_playlist_title(link) + "\"",
		"--cookies-from-browser", web_browser,
		"--embed-metadata",
		"--no-playlist"
		#"--yes-playlist" if is_playlist else "--no-playlist",
		#"--newline
	]
	
	args.append_array(ARG_BINDINGS[format])
	args.append_array(ARG_BINDINGS[quality])
	
	progress_hook["is_audio"] = true
	
	var request_call : Callable = Callable(create_request.bindv([progress_hook, true, args, Binary.YTDLP, false, false, false, true, Util.create_temp_unique_id()]))
	queue.append(request_call)
	request_queue()
	return request_call

func download_video(link : String, output_dir : String, file_name_format: String, format : String, quality : String, muted : bool = false, progress_hook : Dictionary = DEFAULT_PROGRESS_HOOK.duplicate()):
	var args : Array[String] = [
		"\"" + link + "\"",
		"-o", "\"" + format_filename(file_name_format).replace("[quality]", "%(height)sp") + ".%(ext)s" + "\"",
		"-P", "\"" + output_dir + "/" + await  get_playlist_title(link) + "\"",
		"--cookies-from-browser", web_browser,
		"--embed-metadata",
		"--no-playlist"
		#"--yes-playlist" if is_playlist else "--no-playlist",
		#"--newline",
	]
	
	if muted: args.append("--mute")
	
	#args.append_array(ARG_BINDINGS[codec])
	args.append_array(ARG_BINDINGS[format])
	args.append_array(ARG_BINDINGS[quality])
	
	var request_call : Callable = Callable(create_request.bindv([progress_hook, false, args, Binary.YTDLP, false, false, false, true, Util.create_temp_unique_id()]))
	queue.append(request_call)
	request_queue()
	return request_call
	
	#var runtime_info : Dictionary = run(args, Binary.YTDLP, false, false, false, true)
	#update_progress(runtime_info, progress_hook, false)
	#return progress_hook

func wait_until_pipe_output(pipe : FileAccess, pid : int):
	var out : String = ""
	while OS.is_process_running(pid):
		out += pipe.get_as_text()
		await get_tree().process_frame
		
	return out

func get_playlist_title(link : String) -> String:
	var args : Array = ["\"" + link + "\"", "--cookies-from-browser", web_browser]
	args += ARG_BINDINGS["has_playlist"]
	
	var playlist_test : Dictionary = run(args, Binary.YTDLP, false, true, false, true)
	
	var response_string : String = await wait_until_pipe_output(playlist_test["stdio"], playlist_test["pid"])
	
	if not response_string.contains("NA"):
		print("is playlist")
		var title : String = response_string.split("\n")[0]
		
		# A valid file name cannot be empty, begin or end with space characters, or contain characters that are not allowed (: / \ ? * " | % < >)
		if title == "": title = "Unknown"
			
		while title.begins_with(" "): title.erase(0)
		while title.ends_with(" "): title.erase(-1)
		
		for key : String in FILE_CHARACTER_REPLACEMENT.keys():
			title = title.replace(key, FILE_CHARACTER_REPLACEMENT[key])
		
		return title
		
	else:
		print("is not playlist")
		return ""

func create_request(progress_hook : Dictionary, using_audio : bool , args : Array[String], binary : Binary = Binary.YTDLP, console : bool = false, print_output : bool = false, block : bool = true, print_input : bool = false, id : int = 0):
	print("run progress_hook")
	
	
	var runtime_info : Dictionary = run(args, binary, console, print_output, block, print_input)
	update_progress(runtime_info, progress_hook, using_audio)
	return progress_hook

var current_hook : Dictionary

func request_queue():
	#print("request a: ", queue.size() == 0, " ", current_hook.has("done") and current_hook["done"] == false)
	
	if queue.size() == 0 or (current_hook.has("done") and current_hook["done"] == false): 
		print("queue is currently active! waiting..")
		return
	
	var next : Callable = queue.pop_front()
	var hook : Dictionary = next.call() 
	
	current_request = next
	current_hook = hook
	new_hook.emit(hook, next)
	##await Util.wait(5.0)
	#current_hook["done"] = true


func KILL_ALL_CHILDREN(): # MWHAHAHAHAHAHAHHA!!!
	for pid : int in child_processes_ids:
		OS.kill(pid)

func  _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		KILL_ALL_CHILDREN()
		get_tree().quit()
