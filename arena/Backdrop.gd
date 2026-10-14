# Placeholder night-Seoul scenery for the two test rooms. Grey-box level art, not
# the real look: enough to judge how much sky, signs and street each view can show.
extends Node2D
var top: bool = false
var size: Vector2 = Vector2(640,360)
var ledges: Array[Rect2] = []
var font: Font

const SIGNS: Array = [["24시","ff5a6e"],["노래방","ff7ad9"],["약국","6ef0a0"],["호프","ffc857"],["PC방","5ad1ff"],["세탁","c9a7ff"]]

func _ready() -> void:
	font = ThemeDB.fallback_font
	z_index = -10

func _sky(rect: Rect2) -> void:
	var colors: PackedColorArray = [Color("0d1026"),Color("0d1026"),Color("3a2c55"),Color("3a2c55")]
	draw_polygon(PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]),colors)

func _skyline(base: float, from: float, to: float, color: Color, seed_value: int, tall: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var x: float = from
	while x < to:
		var w: float = rng.randf_range(18,46)
		var h: float = rng.randf_range(tall*0.3,tall)
		draw_rect(Rect2(x,base-h,w,h),color)
		x += w+rng.randf_range(0,4)

func _sign(at: Vector2, index: int, vertical: bool = false) -> void:
	var item: Array = SIGNS[index%SIGNS.size()]
	var text: String = item[0]
	var color: Color = Color(item[1])
	var font_size: int = 11
	var box: Vector2 = Vector2(text.length()*12+10,18) if not vertical else Vector2(18,text.length()*13+8)
	draw_rect(Rect2(at,box),Color(0.05,0.05,0.1,0.9))
	draw_rect(Rect2(at-Vector2(2,2),box+Vector2(4,4)),Color(color,0.25),false,4)
	draw_rect(Rect2(at,box),color,false,1.5)
	if vertical:
		for i: int in text.length(): draw_string(font,at+Vector2(3,15+i*13),text[i],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
	else:
		draw_string(font,at+Vector2(5,13),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _windows(rect: Rect2, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var y: float = rect.position.y+8
	while y < rect.end.y-10:
		var x: float = rect.position.x+6
		while x < rect.end.x-8:
			if rng.randf() < 0.45: draw_rect(Rect2(x,y,6,8),Color(1,0.82,0.48,rng.randf_range(0.35,0.8)))
			x += 12
		y += 16

func _draw() -> void:
	if top: _draw_top()
	else: _draw_side()

func _draw_side() -> void:
	_sky(Rect2(Vector2.ZERO,size))
	draw_circle(Vector2(520,58),14,Color("f3e6c8"))
	draw_circle(Vector2(520,58),24,Color(0.95,0.9,0.78,0.08))
	_skyline(250,0,640,Color("1b1d38"),3,150)
	# Tower on the hill.
	draw_rect(Rect2(140,90,4,90),Color("1b1d38"))
	draw_rect(Rect2(134,108,16,8),Color("1b1d38"))
	draw_circle(Vector2(142,88),2,Color("ff5a6e"))
	_skyline(300,0,640,Color("12142a"),8,110)
	# Buildings framing the rooftop, with signs.
	for rect: Rect2 in [Rect2(20,120,70,200),Rect2(250,190,150,130),Rect2(550,90,70,230)]:
		draw_rect(rect,Color("181a30"))
		_windows(rect,int(rect.position.x))
	_sign(Vector2(34,150),0,true)
	_sign(Vector2(286,198),3)
	_sign(Vector2(566,110),1,true)
	# Rooftop floor and side walls.
	draw_rect(Rect2(0,320,640,40),Color("22253a"))
	draw_line(Vector2(0,320),Vector2(640,320),Color("5a5f80"),2)
	draw_rect(Rect2(0,0,20,360),Color("101222"))
	draw_rect(Rect2(620,0,20,360),Color("101222"))
	for ledge: Rect2 in ledges:
		draw_rect(Rect2(ledge.position,Vector2(ledge.size.x,6)),Color("8a8f99"))
		draw_line(ledge.position+Vector2(6,6),ledge.position+Vector2(6,26),Color("4a4f66"),2)
		draw_line(ledge.position+Vector2(ledge.size.x-6,6),ledge.position+Vector2(ledge.size.x-6,26),Color("4a4f66"),2)

func _draw_top() -> void:
	# Sky strip and far skyline above the shop fronts.
	_sky(Rect2(0,0,size.x,48))
	_skyline(48,0,size.x,Color("1b1d38"),5,36)
	# Shop fronts: the solid top edge of the street.
	var x: float = 0
	var index: int = 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	while x < size.x:
		var w: float = rng.randf_range(100,150)
		var front: Rect2 = Rect2(x,40,w,90)
		draw_rect(front,[Color("20223a"),Color("262038"),Color("1c2436")][index%3])
		_windows(Rect2(x,40,w,40),index)
		draw_rect(Rect2(x+8,96,w-16,32),Color(1,0.8,0.45,0.28))
		draw_rect(Rect2(x+8,96,w-16,32),Color("0f1020"),false,2)
		_sign(Vector2(x+w/2-24,78),index)
		draw_rect(Rect2(x+w-22,58,14,10),Color("8a8f99")) # air conditioner
		x += w
		index += 1
	# Sidewalk, curb and wet road.
	draw_rect(Rect2(0,130,size.x,34),Color("2e3048"))
	draw_line(Vector2(0,164),Vector2(size.x,164),Color("6a6f90"),2)
	draw_rect(Rect2(0,166,size.x,size.y-166),Color("15172a"))
	for i: int in int(size.x/60): draw_rect(Rect2(i*60+10,300,30,4),Color("c9c9a0",0.5))
	# Sign reflections on the wet road and street-light pools.
	x = 0
	index = 0
	rng.seed = 11
	while x < size.x:
		var w: float = rng.randf_range(100,150)
		var color: Color = Color(SIGNS[index%SIGNS.size()][1])
		draw_set_transform(Vector2(x+w/2,200),0,Vector2(1,0.3))
		draw_circle(Vector2.ZERO,26,Color(color,0.12))
		draw_set_transform(Vector2.ZERO)
		x += w
		index += 1
	for p: Vector2 in [Vector2(150,260),Vector2(480,350),Vector2(800,240)]:
		draw_set_transform(p,0,Vector2(1,0.45))
		draw_circle(Vector2.ZERO,70,Color(1,0.85,0.5,0.06))
		draw_circle(Vector2.ZERO,40,Color(1,0.85,0.5,0.06))
		draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(0,0,16,size.y),Color("0b0c18"))
	draw_rect(Rect2(size.x-16,0,16,size.y),Color("0b0c18"))
	draw_rect(Rect2(0,size.y-16,size.x,16),Color("0b0c18"))
