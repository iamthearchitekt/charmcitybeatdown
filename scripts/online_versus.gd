extends RefCounted
## A two-player room over a WebSocket relay. Both peers run the fight from identical raw inputs.

const ROOM_ALPHABET="ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const ROOM_CODE_LENGTH=8
const INPUT_DELAY=4
const MAX_LEAD=16
const CHECK_INTERVAL=120
const CONNECT_TIMEOUT_MS=80000
const RECONNECT_INTERVAL_MS=3000
const TIMEOUT_MS=12000
const MAX_INPUT=(1<<11)-1
const ROOM_ERRORS={
	"missing":"ROOM NOT FOUND. CHECK THE CODE.",
	"full":"THAT ROOM ALREADY HAS TWO PLAYERS.",
	"expired":"ROOM CODE EXPIRED. CREATE A NEW ROOM.",
	"busy":"THE ROOM SERVICE IS BUSY. TRY AGAIN.",
	"left":"OPPONENT LEFT THE ROOM.",
	"invalid":"THE ROOM RECEIVED INVALID MATCH DATA.",
}
enum {HELLO, PICK, STAGE, START, LOADED, INPUT, REMATCH, CHECK, LEAVE, PING, PONG}

var state="idle"
var status=""
var room_code=""
var relay_url=""
var local_slot=0
var picks=[0,1]
var ready=[false,false]
var rematch=[false,false]
var match_id=0
var stage_index=0
var turbo=false
var play_frame=0
var send_frame=0
var waiting_ticks=0
var _socket:WebSocketPeer
var _paired=false
var _deadline=0
var _connect_path=""
var _retry_at=0
var _ping_sent=0
var _next_ping=0
var _ping_ms=0
var _fingerprint=PackedByteArray()
var _loaded=[false,false]
var _inputs=[{},{}]
var _checks=[{},{}]
var _fighter_count:int
var _stage_count:int
var _next_remote_frame=0

func _init(fighter_count:int,stage_count:int):
	_fighter_count=fighter_count
	_stage_count=stage_count
	var config=JSON.parse_string(FileAccess.get_file_as_string("res://data/online-relay.json"))
	if config is Dictionary: relay_url=str(config.get("url","")).strip_edges().trim_suffix("/")

static func clean_code(value:String)->String:
	return value.strip_edges().to_upper().replace("-","").replace(" ","")

static func valid_code(value:String)->bool:
	if value.length()!=ROOM_CODE_LENGTH: return false
	for character in value:
		if not character in ROOM_ALPHABET: return false
	return true

func host()->Error:
	close()
	return _connect("/create","CREATING ROOM")

func join(code:String)->Error:
	close()
	var normalized=clean_code(code)
	if not valid_code(normalized):
		status="ENTER THE 8-CHARACTER ROOM CODE."
		return ERR_INVALID_PARAMETER
	local_slot=1
	return _connect("/join/"+normalized,"JOINING ROOM")

func _connect(path:String,message:String)->Error:
	if relay_url.is_empty():
		close("THE ONLINE ROOM SERVICE IS NOT CONFIGURED.")
		return ERR_UNCONFIGURED
	_connect_path=path
	var error=_open_socket()
	if error!=OK:
		close("COULD NOT REACH THE ROOM SERVICE.")
		return error
	state="connecting"
	status=message
	_deadline=Time.get_ticks_msec()+CONNECT_TIMEOUT_MS
	return OK

func _open_socket()->Error:
	_socket=WebSocketPeer.new()
	_socket.inbound_buffer_size=8192
	_socket.outbound_buffer_size=8192
	_socket.max_queued_packets=128
	return _socket.connect_to_url(relay_url+_connect_path)

func close(message:String=""):
	if _socket!=null:
		_socket.close()
		_socket=null
	state="idle"
	status=message
	room_code=""
	local_slot=0
	_paired=false
	_deadline=0
	_connect_path=""
	_retry_at=0
	_ping_sent=0
	_next_ping=0
	_ping_ms=0
	match_id=0
	stage_index=0
	picks=[0,1]
	ready=[false,false]
	rematch=[false,false]
	_loaded=[false,false]
	_inputs=[{},{}]
	_checks=[{},{}]
	waiting_ticks=0

func leave():
	if _paired: _send(PackedByteArray([LEAVE]))
	close()

func poll():
	var now=Time.get_ticks_msec()
	if _deadline>0 and now>_deadline:
		close("CONNECTION TIMED OUT.")
		return
	if _socket==null:
		if state=="connecting" and now>=_retry_at and _open_socket()!=OK:
			_socket=null
			_retry_at=now+RECONNECT_INTERVAL_MS
		return
	_socket.poll()
	while _socket!=null and _socket.get_available_packet_count()>0:
		var packet=_socket.get_packet()
		if _socket.was_string_packet(): _relay_message(packet.get_string_from_utf8())
		elif _paired and not packet.is_empty(): _receive(packet)
	if _socket==null: return
	if _socket.get_ready_state()==WebSocketPeer.STATE_CLOSED:
		if state=="connecting":
			_socket=null
			_retry_at=now+RECONNECT_INTERVAL_MS
			status="CONNECTING TO ROOM SERVICE"
			return
		close("CONNECTION LOST." if _paired else "COULD NOT REACH THE ROOM SERVICE.")
		return
	if state in ["select","match"] and Time.get_ticks_msec()>=_next_ping:
		_ping_sent=Time.get_ticks_msec()
		_next_ping=_ping_sent+2000
		var packet=PackedByteArray([PING,0,0,0,0])
		packet.encode_u32(1,_ping_sent&0xffffffff)
		_send(packet)

func _relay_message(text:String):
	var message=JSON.parse_string(text)
	if not message is Dictionary: return
	match message.get("type",""):
		"room":
			var code=str(message.get("code",""))
			if state!="connecting" or local_slot!=0 or not valid_code(code): return
			room_code=code
			state="listening"
			status="WAITING FOR PLAYER 2"
			_deadline=0
		"paired":
			if state not in ["connecting","listening"]: return
			_paired=true
			_socket.set_no_delay(true)
			state="handshake"
			status="CHECKING GAME VERSION"
			_deadline=Time.get_ticks_msec()+TIMEOUT_MS
			var hello=PackedByteArray([HELLO])
			hello.append_array(_game_fingerprint())
			_send(hello)
		"error": close(ROOM_ERRORS.get(message.get("reason",""),"CONNECTION LOST."))

func _game_fingerprint()->PackedByteArray:
	if not _fingerprint.is_empty(): return _fingerprint
	var digest=HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	for path in [
		"scripts/online_versus.gd","scripts/main.gd","scripts/combat.gd","scripts/commands.gd",
		"scripts/combat_pose.gd","scripts/stage_props.gd","scripts/grapple_sequences.gd",
		"scripts/collision_profiles.gd","data/pose-cutouts.json","data/moves.json","data/collision-profiles.json"
	]:
		digest.update(FileAccess.get_file_as_bytes("res://"+path))
	_fingerprint=digest.finish()
	return _fingerprint

func _send(packet:PackedByteArray)->bool:
	if _socket==null or not _paired: return false
	if _socket.put_packet(packet)!=OK:
		close("CONNECTION LOST.")
		return false
	return true

func _receive(packet:PackedByteArray):
	var other=1-local_slot
	match packet[0]:
		HELLO:
			if state!="handshake": return
			if packet.slice(1)!=_game_fingerprint():
				close("GAME VERSIONS DIFFER. BOTH PLAYERS NEED THE SAME BUILD.")
				return
			state="select"
			status=""
			_deadline=0
		PICK:
			if state!="select" or packet.size()!=3 or packet[1]>=_fighter_count or packet[2]>1 or ready[other]: return
			picks[other]=packet[1]
			ready[other]=packet[2]==1
		STAGE:
			if local_slot==1 and state=="select" and packet.size()==2 and packet[1]<_stage_count:
				stage_index=packet[1]
		START:
			if local_slot!=1 or packet.size()!=7 or packet[1]>=_stage_count or packet[2]>1: return
			if not can_start() or packet.decode_u32(3)!=match_id+1: return
			_begin(packet[1],packet[2]==1)
		LOADED:
			if state=="match" and packet.size()==5 and packet.decode_u32(1)==match_id:
				_loaded[other]=true
		INPUT:
			if state!="match" or packet.size()!=11 or packet.decode_u32(1)!=match_id: return
			var frame=packet.decode_u32(5)
			var input=packet.decode_u16(9)
			if frame!=_next_remote_frame or frame>play_frame+INPUT_DELAY+MAX_LEAD*2 or input>MAX_INPUT or (input&3)==3:
				close("INVALID MATCH INPUT.")
				return
			_inputs[other][frame]=input
			_next_remote_frame+=1
		REMATCH:
			if state=="match" and packet.size()==5 and packet.decode_u32(1)==match_id:
				rematch[other]=true
		CHECK:
			if state!="match" or packet.size()!=13 or packet.decode_u32(1)!=match_id: return
			var frame=packet.decode_u32(5)
			if frame>0 and frame%CHECK_INTERVAL==0 and absi(frame-play_frame)<=CHECK_INTERVAL:
				_record_check(other,frame,packet.decode_u32(9))
		LEAVE:
			if packet.size()==1: close("OPPONENT LEFT THE ROOM.")
		PING:
			if packet.size()==5:
				packet[0]=PONG
				_send(packet)
		PONG:
			if packet.size()==5 and _ping_sent>0 and packet.decode_u32(1)==(_ping_sent&0xffffffff):
				_ping_ms=Time.get_ticks_msec()-_ping_sent
				_ping_sent=0

func choose(kind:int,confirmed:bool=false):
	if state!="select" or ready[local_slot] or kind<0 or kind>=_fighter_count: return
	picks[local_slot]=kind
	ready[local_slot]=confirmed
	_send(PackedByteArray([PICK,kind,int(confirmed)]))

func choose_stage(index:int):
	if local_slot!=0 or state!="select" or not can_start(): return
	if index<0 or index>=_stage_count or index==stage_index: return
	stage_index=index
	_send(PackedByteArray([STAGE,stage_index]))

func can_start()->bool:
	return (state=="select" and ready[0] and ready[1]) or (state=="match" and rematch[0] and rematch[1])

func start(index:int,use_turbo:bool):
	if local_slot!=0 or not can_start() or index<0 or index>=_stage_count: return
	var packet=PackedByteArray([START,index,int(use_turbo),0,0,0,0])
	packet.encode_u32(3,match_id+1)
	if _send(packet): _begin(index,use_turbo)

func _begin(index:int,use_turbo:bool):
	state="match"
	stage_index=index
	turbo=use_turbo
	match_id+=1
	_loaded=[false,false]
	rematch=[false,false]
	_inputs=[{},{}]
	_checks=[{},{}]
	play_frame=0
	send_frame=INPUT_DELAY
	_next_remote_frame=INPUT_DELAY
	waiting_ticks=0
	for player in 2:
		for frame in INPUT_DELAY: _inputs[player][frame]=0

func _match_packet(kind:int,length:int)->PackedByteArray:
	var packet=PackedByteArray()
	packet.resize(length)
	packet[0]=kind
	packet.encode_u32(1,match_id)
	return packet

func mark_loaded():
	if state=="match" and not _loaded[local_slot]:
		_loaded[local_slot]=true
		_send(_match_packet(LOADED,5))

func vote_rematch():
	if state=="match" and not rematch[local_slot]:
		rematch[local_slot]=true
		_send(_match_packet(REMATCH,5))

func can_sample()->bool:
	return state=="match" and _loaded[0] and _loaded[1] and send_frame<play_frame+INPUT_DELAY+MAX_LEAD

func submit(input:int):
	if not can_sample(): return
	var packet=_match_packet(INPUT,11)
	packet.encode_u32(5,send_frame)
	packet.encode_u16(9,input)
	if _send(packet):
		_inputs[local_slot][send_frame]=input
		send_frame+=1

func catch_up()->bool:
	return send_frame-play_frame>INPUT_DELAY+2

func take_frame()->Array:
	if state!="match" or not _loaded[0] or not _loaded[1] or not _inputs[0].has(play_frame) or not _inputs[1].has(play_frame):
		waiting_ticks+=1
		return []
	var input=[_inputs[0][play_frame],_inputs[1][play_frame]]
	for player in 2: _inputs[player].erase(play_frame)
	play_frame+=1
	waiting_ticks=0
	return input

func ping_ms()->int:
	return _ping_ms

func check_sync(checksum:int):
	if state!="match" or play_frame%CHECK_INTERVAL!=0: return
	var packet=_match_packet(CHECK,13)
	packet.encode_u32(5,play_frame)
	packet.encode_u32(9,checksum&0xffffffff)
	_record_check(local_slot,play_frame,packet.decode_u32(9))
	_send(packet)

func _record_check(slot:int,frame:int,value:int):
	var other=1-slot
	if _checks[other].has(frame):
		if _checks[other][frame]!=value: close("MATCH LOST SYNC. HOST A NEW ROOM.")
		else: _checks[other].erase(frame)
	else:
		_checks[slot][frame]=value
		_checks[slot].erase(frame-2*CHECK_INTERVAL)
