extends RefCounted
# Controller-only configuration. Keyboard bindings never pass through this class.
const STEPS=["left","right","up","down","lp","mp","hp","lk","mk","hk","throw","throw_right"]
const LABELS=["D-PAD LEFT","D-PAD RIGHT","D-PAD UP","D-PAD DOWN","A  /  LIGHT PUNCH","B  /  MEDIUM PUNCH","C  /  HEAVY PUNCH","X  /  LIGHT KICK","Y  /  MEDIUM KICK","Z  /  HEAVY KICK","L  /  GRAPPLE","R  /  GRAPPLE"]
const ACTIONS=["lp","mp","hp","lk","mk","hk","throw","throw_right","pause","confirm","back","cheat_clear"]
const ATTACK_LAYOUT_VERSION=2
# The user's confirmed primary controller is a Retro-Bit Sega pad. Windows may
# identify it as an Xbox/ generic device, so its layout cannot rely on the name.
var primary_layout="retrobit"
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
	var buttons={"left":JOY_BUTTON_DPAD_LEFT,"right":JOY_BUTTON_DPAD_RIGHT,"up":JOY_BUTTON_DPAD_UP,"down":JOY_BUTTON_DPAD_DOWN,"lp":JOY_BUTTON_X,"mp":JOY_BUTTON_Y,"hp":JOY_BUTTON_RIGHT_SHOULDER,"lk":JOY_BUTTON_A,"mk":JOY_BUTTON_B,"throw":JOY_BUTTON_LEFT_SHOULDER,"pause":JOY_BUTTON_START,"confirm":JOY_BUTTON_A,"back":JOY_BUTTON_B}
	for action in buttons: result[action]={"button":buttons[action]}
	result.hk={"axis":JOY_AXIS_TRIGGER_RIGHT,"sign":1}
	result.throw_right={"axis":JOY_AXIS_TRIGGER_LEFT,"sign":1}
	return result

func mapping(id:int)->Dictionary:
	var identity=devices.get(id,"")
	var saved:Dictionary=profiles.get(identity,{})
	var name=identity.to_lower().replace("-","").replace(" ","")
	var sega=(slots.find(id)==0 and primary_layout=="retrobit") or "retrobit" in name
	if saved.has_all(STEPS):
		var effective=saved.duplicate()
		var bottom_punches=int(saved.get("attack_layout",1))>=ATTACK_LAYOUT_VERSION
		if sega and not bottom_punches: swap_attack_rows(effective)
		effective.cheat_clear=effective.hp if sega or bottom_punches else effective.hk
		return effective
	var result=defaults()
	if sega:
		# On Retro-Bit Bluetooth, physical Z and C report as trigger axes.
		result.hp={"axis":JOY_AXIS_TRIGGER_LEFT,"sign":1}
		result.throw_right={"button":JOY_BUTTON_RIGHT_SHOULDER}
		swap_attack_rows(result)
	result.cheat_clear=result.hp if sega else result.hk
	# Preserve calibrated directions from older profiles. The former attack
	# layout is replaced as a group to avoid duplicate face/shoulder mappings.
	for direction in STEPS.slice(0,4):
		if saved.has(direction): result[direction]=saved[direction]
	return result

func swap_attack_rows(bindings:Dictionary):
	for pair in [["lp","lk"],["mp","mk"],["hp","hk"]]:
		var punch=bindings[pair[0]]
		bindings[pair[0]]=bindings[pair[1]]
		bindings[pair[1]]=punch

func save_mapping(id:int,bindings:Dictionary)->Error:
	if not devices.has(id): return ERR_DOES_NOT_EXIST
	var identity=devices[id]
	var old=profiles.duplicate(true)
	profiles[identity]=bindings.duplicate(true)
	profiles[identity].attack_layout=ATTACK_LAYOUT_VERSION
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
	if not profiles.get(devices.get(id,""),{}).has("left"):
		var x=axes.get(id,{}).get(JOY_AXIS_LEFT_X,0.0)
		var y=axes.get(id,{}).get(JOY_AXIS_LEFT_Y,0.0)
		left=left or x<-.4;right=right or x>.4
		up=up or y<-.4;down=down or y>.4
	return {"dx":int(right)-int(left),"up":up,"down":down}
