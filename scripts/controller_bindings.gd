extends RefCounted
# Controller-only configuration. Keyboard bindings never pass through this class.
const STEPS=["left","right","up","down","lp","hp","lk","hk","throw","pause","confirm","back"]
const LABELS=["D-PAD LEFT","D-PAD RIGHT","D-PAD UP","D-PAD DOWN","LIGHT PUNCH  /  SEGA X","HEAVY PUNCH  /  SEGA Z","LIGHT KICK  /  SEGA A","HEAVY KICK  /  SEGA C","THROW  /  SEGA Y","PAUSE  /  START","MENU CONFIRM  /  SEGA A","MENU BACK  /  SEGA B"]
var path="user://controllers.cfg"
var profiles:Dictionary={}
var slots:Array=[-1,-1]
var identities:Array=["",""]
var devices:Dictionary={}
var held:Dictionary={}
var axes:Dictionary={}
var config=ConfigFile.new()

func _init():
	if config.load(path)==OK:
		profiles=config.get_value("controllers","profiles",{})

func connect_device(id:int,identity:String)->int:
	devices[id]=identity
	var slot=identities.find(identity)
	if slot<0 or slots[slot]!=-1: slot=slots.find(-1)
	if slot>=0:
		slots[slot]=id
		identities[slot]=identity
	return slot

func disconnect_device(id:int)->int:
	var slot=slots.find(id)
	if slot>=0: slots[slot]=-1
	devices.erase(id)
	held.erase(id)
	axes.erase(id)
	return slot

func defaults()->Dictionary:
	var result={}
	var buttons={"left":JOY_BUTTON_DPAD_LEFT,"right":JOY_BUTTON_DPAD_RIGHT,"up":JOY_BUTTON_DPAD_UP,"down":JOY_BUTTON_DPAD_DOWN,"lp":JOY_BUTTON_X,"hp":JOY_BUTTON_Y,"lk":JOY_BUTTON_A,"hk":JOY_BUTTON_B,"throw":JOY_BUTTON_LEFT_SHOULDER,"pause":JOY_BUTTON_START,"confirm":JOY_BUTTON_A,"back":JOY_BUTTON_B}
	for action in buttons: result[action]={"button":buttons[action]}
	return result

func mapping(id:int)->Dictionary:
	return profiles.get(devices.get(id,""),defaults())

func save_mapping(id:int,bindings:Dictionary)->Error:
	if not devices.has(id): return ERR_DOES_NOT_EXIST
	var identity=devices[id]
	var old=profiles.duplicate(true)
	profiles[identity]=bindings.duplicate(true)
	config.set_value("controllers","profiles",profiles)
	var error=config.save(path)
	if error!=OK: profiles=old
	return error

func ingest(event:InputEvent):
	if event is InputEventJoypadButton:
		if not held.has(event.device): held[event.device]={}
		held[event.device][event.button_index]=event.pressed
	elif event is InputEventJoypadMotion:
		if not axes.has(event.device): axes[event.device]={}
		axes[event.device][event.axis]=event.axis_value

func binding_from_event(event:InputEvent)->Dictionary:
	if event is InputEventJoypadButton and event.pressed: return {"button":event.button_index}
	if event is InputEventJoypadMotion and absf(event.axis_value)>.65:
		return {"axis":event.axis,"sign":1 if event.axis_value>0 else -1}
	return {}

func active(id:int,binding:Dictionary)->bool:
	if binding.has("button"): return held.get(id,{}).get(int(binding.button),false)
	if binding.has("axis"): return axes.get(id,{}).get(int(binding.axis),0.0)*binding.sign>.4
	return false

func matches(event:InputEvent,binding:Dictionary)->bool:
	if event is InputEventJoypadButton: return event.pressed and binding.get("button",-1)==event.button_index
	return false

func directions(id:int)->Dictionary:
	var binds=mapping(id)
	var left=active(id,binds.left)
	var right=active(id,binds.right)
	var up=active(id,binds.up)
	var down=active(id,binds.down)
	if not profiles.has(devices.get(id,"")):
		var x=axes.get(id,{}).get(JOY_AXIS_LEFT_X,0.0)
		var y=axes.get(id,{}).get(JOY_AXIS_LEFT_Y,0.0)
		left=left or x<-.4;right=right or x>.4
		up=up or y<-.4;down=down or y>.4
	return {"dx":int(right)-int(left),"up":up,"down":down}
