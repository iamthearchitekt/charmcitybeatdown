extends RefCounted
## One finite run: shuffled roster, two fixed bosses, cumulative score and top ten.
var active=false
var player=0
var opponents:Array=[]
var cursor=0
var score=0
var continues=0
var bonus_index=0
var submitted=false
var high_scores:Array=[]
var scores_path="user://arcade-high-scores.cfg"
var save_error=OK
const BONUS_TYPES=["car","kegs","boxes"]

func _init(): load_scores()

func begin(kind:int,roster:Array,eligible:Array):
	active=true;player=kind;cursor=0;score=0;continues=0;bonus_index=0;submitted=false
	opponents=[]
	var final_boss=pick_boss(["rachel","jeff","stan"],kind,roster,eligible,[])
	var sub_boss=pick_boss(["spike","stan","marcus"],kind,roster,eligible,[final_boss])
	for opponent in eligible:
		if opponent!=kind and opponent not in [sub_boss,final_boss]: opponents.append(opponent)
	opponents.shuffle()
	if sub_boss>=0: opponents.append(sub_boss)
	if final_boss>=0: opponents.append(final_boss)

func pick_boss(ids:Array,kind:int,roster:Array,eligible:Array,excluded:Array)->int:
	for id in ids:
		for i in eligible:
			if i!=kind and i not in excluded and roster[i].id==id: return i
	return -1

func opponent()->int: return int(opponents[cursor]) if cursor<opponents.size() else -1
func complete()->bool: return active and cursor>=opponents.size()
func won_match(points:int):
	if not active or complete(): return
	score+=maxi(0,points);cursor+=1
func next_bonus()->String:
	var kind=BONUS_TYPES[bonus_index%BONUS_TYPES.size()]
	bonus_index+=1
	return kind
func load_scores():
	var config=ConfigFile.new()
	high_scores=[]
	if config.load(scores_path)==OK:
		for entry in config.get_value("arcade","scores",[]):
			if entry is Dictionary and entry.has_all(["name","score","clear","continues"]): high_scores.append(entry)
func submit(name:String,cleared:bool):
	if submitted: return
	submitted=true
	if score<=0: return
	high_scores.append({"name":name,"score":score,"clear":cleared,"continues":continues})
	high_scores.sort_custom(func(a,b):return int(a.score)>int(b.score))
	if high_scores.size()>10: high_scores.resize(10)
	var config=ConfigFile.new();config.set_value("arcade","scores",high_scores)
	save_error=config.save(scores_path)
	if save_error!=OK: push_warning("Could not save arcade high scores: "+error_string(save_error))
