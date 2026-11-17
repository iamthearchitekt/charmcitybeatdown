extends AudioStreamPlayer
# A dedicated voice keeps announcements out of the impact sound pool.
var clips:Dictionary={}
var pending:Array=[]
var playback_log:Array=[]
func _ready():
	for entry in [["fight","2B_announcer_fight.wav"],["you","40_announcer_you.wav"],["win","41_announcer_win.wav"],["lose","42_announcer_lose.wav"]]:
		clips[entry[0]]=load("res://audio/sf2-cps1/"+entry[1])
	volume_db=-5
	finished.connect(next_clip)
func say(words:Array):
	clear()
	pending=words.duplicate()
	next_clip()
func next_clip():
	if pending.is_empty(): return
	var word=pending.pop_front()
	stream=clips[word]
	playback_log.append(word)
	if playback_log.size()>32: playback_log.pop_front()
	play()
func clear():
	stop()
	stream_paused=false
	pending.clear()
