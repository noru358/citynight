# Screen-space night sky behind the city: gradient, moon, stars and two parallax
# skylines with deterministic lit windows. Colors come from the chapter's "sky".
extends Node2D
var stage: Node2D
var colors: Dictionary = {
	"top": Color("0d1026"), "bottom": Color("3a2c55"), "glow": Color("c86a6a"),
	"far": Color("1b1d38"), "near": Color("12142a"), "window_warm": Color("f2c27a"), "window_cool": Color("8fb8e8"),
}

func set_colors(values: Dictionary) -> void:
	for key: String in values: colors[key] = Color(str(values[key]))

static func hash01(a: int, b: int) -> float:
	return NightSkyHash.h(a,b)

func _draw() -> void:
	var size: Vector2 = get_viewport_rect().size
	var center: Vector2 = stage.camera.get_screen_center_position()
	var bands: int = 32
	for i: int in bands:
		var k: float = float(i)/(bands-1)
		var color: Color = colors.top.lerp(colors.bottom,k)
		if k > 0.7: color = color.lerp(colors.glow,(k-0.7)/0.3*0.35)
		draw_rect(Rect2(0,size.y*i/bands,size.x,size.y/bands+1),color)
	for i: int in 70:
		var star: Vector2 = Vector2(hash01(i,1)*size.x,hash01(i,2)*size.y*0.55)
		draw_circle(star,1.0+hash01(i,3),Color(1,1,1,0.25+0.5*hash01(i,4)))
	draw_circle(Vector2(size.x*0.78,size.y*0.18),26,Color(0.98,0.93,0.82,0.92))
	draw_circle(Vector2(size.x*0.78,size.y*0.18),44,Color(0.98,0.93,0.82,0.08))
	var zoom: float = stage.camera.zoom.x
	var lift: float = (center.y-stage.map_size.y*0.5)*zoom
	_skyline(size,center.x*zoom*0.12,size.y*0.70-lift*0.08,90,colors.far,0.5,11)
	_skyline(size,center.x*zoom*0.30,size.y*0.80-lift*0.2,130,colors.near,0.8,23)

func _skyline(size: Vector2, offset: float, base: float, height: float, color: Color, window_alpha: float, salt: int) -> void:
	var width: float = 46
	var first: int = int(floor(offset/width))-1
	var x: float = float(first)*width-offset
	var index: int = first
	while x < size.x+width:
		var h: float = height*(0.35+0.65*hash01(index,salt))
		var w: float = width*(0.75+0.25*hash01(index,salt+1))
		var top: float = base-h
		draw_rect(Rect2(x,top,w,size.y-top+2),color)
		var rows: int = int(h/14)
		for row: int in rows:
			for col: int in int(w/10):
				var lit: float = hash01(index*31+col,row*17+salt)
				if lit > 0.82:
					var tint: Color = colors.window_warm if hash01(index+col,row+salt) > 0.3 else colors.window_cool
					tint.a = window_alpha*(0.35+0.4*lit)
					draw_rect(Rect2(x+3+col*10,top+6+row*14,4,6),tint)
		x += width
		index += 1
