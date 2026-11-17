extends RefCounted
## Input history is sampled at 60 Hz even during hitstop. Directions are facing-relative.
var history: Array = []
var clock: int = 0
var last_dir: int = 5
var display: Array = []

func reset():
	history.clear()
	display.clear()
	clock = 0
	last_dir = 5

func sample(direction: int, buttons: Array) -> String:
	clock += 1
	var changed=direction!=last_dir
	if direction != last_dir:
		history.append({"d":direction,"t":clock})
		last_dir = direction
		display.push_front(str(direction))
	while not history.is_empty() and clock - history[0].t > 28:
		history.pop_front()
	for button in buttons:
		display.push_front(button.to_upper())
	while display.size() > 12:
		display.pop_back()
	if buttons.has("lp") or buttons.has("hp"):
		if matches([6,2,3], 24):
			history.clear()
			return "special2"
		if matches([2,3,6], 24):
			history.clear()
			return "special1"
	for button in ["throw","hk","hp","lk","lp"]:
		if buttons.has(button):
			return button
	if changed and direction in [4,6] and history.size()>=3:
		var tail=history.slice(-3)
		if tail[0].d==direction and tail[1].d==5 and tail[2].d==direction and clock-tail[0].t<=14:
			history.clear()
			return "dash_forward" if direction==6 else "dash_back"
	return ""

func matches(pattern: Array, max_age: int) -> bool:
	var cursor = pattern.size()-1
	for i in range(history.size()-1, -1, -1):
		if clock-history[i].t > max_age:
			break
		if history[i].d == pattern[cursor]:
			cursor -= 1
			if cursor < 0:
				return clock-history[-1].t <= 8
	return false

static func relative_direction(dx: int, down: bool, up: bool, facing: int) -> int:
	var x = dx*facing
	if down: return 2+x
	if up: return 8+x
	return 5+x
