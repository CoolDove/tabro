package main

import "core:fmt"
import "core:math/linalg"
import "core:strings"
import "core:math"
import "core:log"

import "core:hash"

import rl "vendor:raylib"
import nvg "vendor:nanovg"
import "tween"
import hla "collections/hollow_array"

Color :: rl.Color
Rect :: rl.Rectangle
Vec2 :: rl.Vector2
Vec4 :: rl.Vector4

VuiWjtHd :: #type hla.HollowArrayHandle(VuiWidget)

VuiContext :: struct {
	hot, active : u64,
	delta_s : f64,

	widgets : map[u64]VuiWjtHd,
	_widgets_pool : hla.HollowArray(VuiWidget),

	widget_stack : [dynamic]VuiWjtHd,
}

VuiLayoutElemProcessor :: #type proc(rect: Rect, data: rawptr)

VuiLayoutElem :: struct {
	process : VuiLayoutElemProcessor,
	rect : Rect,
	data : rawptr,
}

@(private="file")
ctx : VuiContext

_vui_ctx :: proc() -> ^VuiContext {
	return &ctx
}

vui_init :: proc() {
	ctx._widgets_pool = hla.hla_make(VuiWidget, 256)
	ctx.widgets = make(map[u64]hla.HollowArrayHandle(VuiWidget))
	ctx.widget_stack = make([dynamic]VuiWjtHd, 16)
}
vui_release :: proc() {
	delete(ctx.widgets)
	delete(ctx.widget_stack)
	hla.hla_delete(&ctx._widgets_pool)
}

vui_begin :: proc(delta_s: f64, rect: Rect) {
	ctx.delta_s = delta_s
	ctx.hot = 0
	clear(&ctx.widget_stack)
}
vui_end :: proc() {
}

VuiWidget :: struct {
	basic : VuiWidget_Basic,

	clickable : VuiWidget_Clickable,

	draw_rect     : VuiWidget_DrawRect,
	draw_text     : VuiWidget_DrawText,
	draw_custom   : VuiWidget_DrawCustom,

	layout : VuiWidget_LayoutContainer,
}

EXPAND :f32: -1

VuiWidget_Basic :: struct {
	id : u64,
	// priority : u64, // no use currently

	// If in a container, `x` and `y` would be ignored, `width` and `height`
	//	would follow the rule:
	//	<0 : expand, the absolute value would be the minimun size
	//	=0 : 0
	//	>0 : fixed
	rect : Rect,

	ready : bool,
	baked_rect : Rect,

	using _basic_reset : struct {
		children_count : int,
		using _tree : struct {
			parent, child, next, last : VuiWjtHd,
		},
		interact : VuiInteract,
	}
}
VuiWidget_Clickable :: struct {
	enable : bool,
}
VuiWidget_UpdateCustom :: struct {
	enable : bool,
	update : proc(w: VuiWjtHd),
	data : [8*8]u8,
}

VuiWidget_DrawRect :: struct {
	enable : bool,
	box_normal, box_hover, box_active : BoxStyle,
}

VuiWidget_DrawText :: struct {
	enable : bool,
	text : string,
	text_normal, text_hover, text_active : TextStyle,
}
VuiWidget_DrawCustom :: struct {
	enable : bool,
	draw : proc(widget: VuiWjtHd),
	data : rawptr,
}

VuiWidget_LayoutContainer :: struct {
	enable : bool,
	direction : VuiLayoutDirection,
	spacing : f32,
	padding : Vec4, // left, top, right, bottom

	using _layout_reset : struct {
		_used_space : f32,
		_fit_elem_count : int,
	}
}
VuiLayoutDirection :: enum {
	Vertical, Horizontal
}

VuiInteract :: struct {
	clicked : bool,
}

// peek currently openning widget
_vui_peek_current_open_widget :: #force_inline proc() -> (VuiWjtHd, ^VuiWidget) {
	if len(ctx.widget_stack) == 0 do return {}, nil
	handle := ctx.widget_stack[len(ctx.widget_stack)-1]
	return handle, hla.hla_get_pointer(handle)
}

_vuibd_helper_get_current :: _vui_peek_current_open_widget
_vuibd_helper_get_pointer_from_handle :: proc(h: VuiWjtHd) -> ^VuiWidget {
	return hla.hla_get_pointer(h)
}

@(private="file")
_vui_get_widget :: proc(id: u64) -> (VuiWjtHd, ^VuiWidget) {
	s, ok := ctx.widgets[id] 
	if !ok {
		ctx.widgets[id] = hla.hla_append(&ctx._widgets_pool, VuiWidget{})
		s = ctx.widgets[id]
	}
	return s, hla.hla_get_pointer(s)
}


vuid :: proc(label: string) -> u64 {
	return hash.fnv64(transmute([]byte)label)
}

_vuibd_begin :: proc(id: u64, rect: Rect) {
	h, widget := _vui_get_widget(id)
	widget.basic.id = id
	widget.basic.rect = rect
	widget.basic._basic_reset = {}

	widget.clickable.enable               = false

	widget.draw_rect.enable               = false
	widget.draw_text.enable               = false
	widget.draw_custom.enable             = false

	widget.layout.enable                  = false

	if parenth, parent := _vui_peek_current_open_widget(); parent != nil {
		__widget_append_child(parenth, h)
	} else {
		widget.basic.baked_rect = widget.basic.rect
	}

	append(&ctx.widget_stack, h)
}
_vuibd_end :: proc() -> VuiInteract {
	widget := pop(&ctx.widget_stack)
	return _vui_widget_proc(widget)
}
_vuibd_draw_rect :: proc(normal: BoxStyle) -> ^VuiWidget_DrawRect {
	_, widget := _vui_peek_current_open_widget()
	using widget.draw_rect
	enable = true
	box_normal = normal
	box_hover  = normal
	box_active = normal
	return &widget.draw_rect
}
_vuibd_draw_text :: proc(normal: TextStyle, text: string) -> ^VuiWidget_DrawText {
	_, widget := _vui_peek_current_open_widget()
	draw := &widget.draw_text
	draw.enable = true
	draw.text = text
	draw.text_normal = normal
	draw.text_hover  = normal
	draw.text_active = normal
	return draw
}
_vuibd_draw_custom :: proc(draw: proc(w: VuiWjtHd), data: rawptr) {
	widgeth, widget := _vui_peek_current_open_widget()
	widget.draw_custom = { true, draw, data }
}

_vuibd_clickable :: proc() {
	_, widget := _vui_peek_current_open_widget()
	widget.clickable.enable = true
}

_vuibd_layout :: proc(direction: VuiLayoutDirection) -> ^VuiWidget_LayoutContainer {
	_, widget := _vui_peek_current_open_widget()
	layout := &widget.layout
	layout.enable = true
	layout.direction = direction
	layout._layout_reset = {}
	return layout
}

BoxStyle :: struct {
	color : rl.Color,
	round : f32,

	border_color  : rl.Color,
	border_width  : f32,

	shadow_color  : rl.Color,
	shadow_offset : Vec2,
}
TextStyle :: struct {
	size : f32,
	color : rl.Color,

	shadow_color : rl.Color,
	shadow_offset : Vec2,

	clip : bool,
}

@(private="file")
__draw_rect_style :: proc(wjt: ^VuiWidget, using b: BoxStyle) {
	using wjt.basic
	if round <= 0 {
		if shadow_color.a > 0 && shadow_offset != {} {
			if nvg.FillScoped(vg); true {
				nvg.FillColor(vg, col_u2f(shadow_color))
				nvg.Rect(vg, rect.x+shadow_offset.x, rect.y+shadow_offset.y, rect.width, rect.height)
			}
		}
		if nvg.FillScoped(vg); true {
			nvg.FillColor(vg, col_u2f(color))
			nvg.Rect(vg, rect.x, rect.y, rect.width, rect.height)
		}
		if border_width > 0 && border_color.a > 0 {
			nvg.StrokeColor(vg, col_u2f(border_color))
			nvg.Stroke(vg)
		}
	} else {
		if shadow_color.a > 0 && shadow_offset != {} {
			if nvg.FillScoped(vg); true {
				nvg.FillColor(vg, col_u2f(shadow_color))
				nvg.RoundedRect(vg, rect.x+shadow_offset.x, rect.y+shadow_offset.y, rect.width, rect.height, cast(f32)round)
			}
		}
		if nvg.FillScoped(vg); true {
			nvg.FillColor(vg, col_u2f(color))
			nvg.RoundedRect(vg, rect.x, rect.y, rect.width, rect.height, cast(f32)round)
		}
		if border_width > 0 && border_color.a > 0 {
			nvg.StrokeColor(vg, col_u2f(border_color))
			nvg.Stroke(vg)
		}
	}
}
@(private="file")
__draw_text_style :: proc(wjt: ^VuiWidget, using t: TextStyle, text: string) {
	using wjt.basic
	if clip do nvg.Scissor(vg, rect.x, rect.y, rect.width, rect.height)
	defer if clip do nvg.ResetScissor(vg)

	nvg.FontSize(vg, cast(f32)size)
	nvg.TextAlign(vg, .LEFT, .MIDDLE)
	asc,des,line_height := nvg.TextMetrics(vg)
	bounds : [4]f32
	nvg.TextBounds(vg, rect.x, rect.y+cast(f32)size, text, &bounds)
	text_width := bounds.z-bounds.x

	if shadow_color.a != 0 && shadow_offset != {} {
		nvg.FillColor(vg, col_u2f(shadow_color))
		nvg.Text(vg,
			rect.x + (rect.width - text_width) * 0.5 + shadow_offset.x,
			rect.y + rect.height*0.5 + shadow_offset.y,
			text
		)
	}
	nvg.FillColor(vg, col_u2f(color))
	nvg.Text(vg, rect.x + (rect.width - text_width) * 0.5, rect.y + rect.height*0.5, text)
}

@(private="file")
__widget_append_child :: proc(parent, child: VuiWjtHd) {
	parenth := parent
	parent := hla.hla_get_pointer(parent)
	if parent.basic.child == {} {
		parent.basic.child = child
	} else {
		hla.hla_get_pointer(parent.basic.last).basic.next = child
	}
	hla.hla_get_pointer(child).basic.parent = parenth
	parent.basic.last = child
	parent.basic.children_count += 1
}

_vui_widget_proc :: proc(widget: VuiWjtHd) -> VuiInteract {
	widgeth := widget
	widget := hla.hla_get_pointer(widget)
	using widget.basic

	if widget.clickable.enable && widget.basic.ready && widget.basic.id != 0 {
		inrect := rect_in(widget.basic.baked_rect, rl.GetMousePosition())
		if inrect {
			ctx.hot = id
		}
		if ctx.hot == id && rl.IsMouseButtonPressed(.LEFT) {
			interact.clicked = true
		}
	}

	_layout_widget :: proc(widget: VuiWjtHd, pass: int) {
		widgeth := widget
		widget := hla.hla_get_pointer(widget)
		using widget.basic
		// PASS A: sizes
		if pass == 0 && hla.hla_get_pointer(child) != nil {
			layout := &widget.layout
			p := child

			ctnr_rect := widget.basic.rect
			for true {
				s := hla.hla_get_pointer(p) or_break
				_layout_widget(p, 0)
				using s.basic
				if layout.enable {
					switch layout.direction {
					case .Vertical:
						if rect.height < 0 {
							layout._fit_elem_count += 1
						} else {
							layout._used_space += rect.height
						}
						ctnr_rect.width = ctnr_rect.width if ctnr_rect.width < 0 else math.max(rect.width + layout.padding.x + layout.padding.z, ctnr_rect.width)
					case .Horizontal:
						if rect.width < 0 {
							layout._fit_elem_count += 1
						} else {
							layout._used_space += rect.width
						}
						ctnr_rect.height = ctnr_rect.height if ctnr_rect.height < 0 else math.max(rect.height + layout.padding.y + layout.padding.w, ctnr_rect.height)
					}
				}
				p = next
			}

			widget.basic.rect = ctnr_rect
		}

		// PASS B: positions
		if pass == 1 && hla.hla_get_pointer(child) != nil {
			layout := &widget.layout
			container_rect := widget.basic.rect
			position :Vec2= {container_rect.x, container_rect.y}
			if layout.enable {
				position += {layout.padding.x, layout.padding.y}
			}

			p := child
			for true {
				s := hla.hla_get_pointer(p) or_break
				using s.basic
				if layout.enable {
					switch layout.direction {
					case .Vertical:
						rect.x = position.x
						rect.y = position.y
						if rect.width < 0 do rect.width = container_rect.width - layout.padding.x - layout.padding.z
						available_space := container_rect.height - layout.padding.y - layout.padding.w - layout._used_space - f32(widget.basic.children_count-1) * layout.spacing
						if rect.height < 0 {
							if available_space < -rect.height {
								rect.height = -rect.height
							} else {
								rect.height = available_space / f32(layout._fit_elem_count)
							}
						}
						position += {0, rect.height + cast(f32)layout.spacing}
					case .Horizontal:
						rect.x = position.x
						rect.y = position.y
						if rect.height < 0 do rect.height = container_rect.height - layout.padding.y - layout.padding.w
						available_space :f32= container_rect.width - layout.padding.x - layout.padding.z - layout._used_space - f32(widget.basic.children_count-1) * layout.spacing
						if rect.width < 0 {
							if available_space < -rect.width {
								rect.width = -rect.width
							} else {
								rect.width = available_space / f32(layout._fit_elem_count)
							}
						}
						position += {rect.width + cast(f32)layout.spacing, 0}
					}
				}
				_layout_widget(p, 1)
				p = next
				baked_rect = rect
			}
		}
		widget.basic.ready = true
	}
	if _, parent := _vui_peek_current_open_widget(); parent == nil {
		_layout_widget(widgeth, 0)
		_layout_widget(widgeth, 1)
	}

	_draw_widget :: proc(widget: VuiWjtHd) {
		widgeth := widget
		widget := hla.hla_get_pointer(widget)
		using widget.basic

		if widget.draw_rect.enable {
			using widget.draw_rect
			rect := widget.basic.baked_rect
			if widget.basic.id != ctx.hot {
				__draw_rect_style(widget, box_normal)
			} else {
				if widget.basic.interact.clicked {
					__draw_rect_style(widget, box_active)
				} else {
					__draw_rect_style(widget, box_hover)
				}
			}
		}

		if widget.draw_text.enable {
			using widget.draw_text
			if widget.basic.id != ctx.hot {
				__draw_text_style(widget, text_normal, text)
			} else {
				if widget.basic.interact.clicked {
					__draw_text_style(widget, text_active, text)
				} else {
					__draw_text_style(widget, text_hover, text)
				}
			}
		}
		if widget.draw_custom.enable {
			using widget.draw_custom
			draw(widgeth)
		}

		// draw child tree
		if hla.hla_get_pointer(child) != nil {
			p := child
			for true {
				s := hla.hla_get_pointer(p)
				if s == nil do break
				_draw_widget(p)
				p = s.basic.next
			}
		}
	}

	if _, parent := _vui_peek_current_open_widget(); parent == nil {
		_draw_widget(widgeth)
	}

	return interact
}

rect_in :: proc(rect: Rect, pos: Vec2) -> bool {
	return !(pos.x < rect.x || pos.y < rect.y || pos.x > rect.x+rect.width || pos.y > rect.y+rect.height)
}

col_u2f :: proc(color : Color) -> Vec4 {
	return {(cast(f32)color.x)/255.0, (cast(f32)color.y)/255.0, (cast(f32)color.z)/255.0, (cast(f32)color.w)/255.0}
}
col_f2u :: proc(color : Vec4) -> Color {
	return {cast(u8)(color.x*255.0), cast(u8)(color.y*255.0), cast(u8)(color.z*255.0), cast(u8)(color.w*255.0)}
}
col_i2u :: proc(color: u32) -> Color {
	return transmute(Color)color
}
col_i2u_inv :: proc(color: u32) -> Color {
	color := transmute(Color)color
	color[0], color[1], color[2], color[3] = color[3], color[2], color[1], color[0] 
	return color
}
