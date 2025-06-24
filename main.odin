package main

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"
import nvg "vendor:nanovg"

vg : ^nvg.Context

fontid_default : int

ui_font_size :f32= 28

main :: proc() {
	rl.SetTargetFPS(60)
	rl.SetWindowState({.WINDOW_RESIZABLE})
	rl.InitWindow(800, 600, "Tabro"); defer rl.CloseWindow()
	vg = draw_init(); defer draw_release(vg)

	fontid_default = nvg.CreateFont(vg, "xwwk", "LXGWWenKai-Regular.ttf")
	// fontid_default = nvg.CreateFont(vg, "xwwk", "IosevkaTermSlabNerdFontMono-Regular.ttf")

	vui_init(); defer vui_release()

	offset := rl.Vector2{0,0}
	frame :rl.Rectangle= {10,10, 400, 30}

	for !rl.WindowShouldClose() {
		// update
		scrn_width, scrn_height :f32= cast(f32)rl.GetScreenWidth(), cast(f32)rl.GetScreenHeight()
		spd :f32= 60.0
		if rl.IsKeyDown(.J) {
			if rl.IsKeyDown(.LEFT_SHIFT) {
				frame.height += spd/60.0
			} else {
				offset.y -= spd/60.0
			}
		}
		if rl.IsKeyDown(.K) {
			if rl.IsKeyDown(.LEFT_SHIFT) {
				frame.height -= spd/60.0
			} else {
				offset.y += spd/60.0
			}
		}

		// draw
		rl.BeginDrawing(); defer rl.EndDrawing()
		rl.ClearBackground(rl.GRAY)

		nvg.BeginFrame(vg, scrn_width, scrn_height, 1.0)
		defer {
			nvg.Restore(vg)
			nvg.EndFrame(vg)
		}

		if nvg.StrokeScoped(vg); true {
			nvg.StrokeWidth(vg, 2)
			nvg.StrokeColor(vg, {0,1,0, 1})
			nvg.RoundedRect(vg, frame.x, frame.y, frame.width, frame.height, 4)
		}

		nvg.Scissor(vg, frame.x, frame.y, frame.width, frame.height)
			nvg.FillColor(vg, {0,1,1, 1})
			nvg.FontSize(vg, 32)
			nvg.TextBox(vg, 10+offset.x, 10+32-3+offset.y, 1000, #load("main.odin"))
		nvg.ResetScissor(vg)

		vui_begin(
			1.0/60.0,
			{0,0, scrn_width, scrn_height}
		)
		defer vui_end()

		{
			_vuibd_begin(0, {20, 140, 320, 400})
			_vuibd_draw_rect({ color= {120,130,200, 255} })
			_vuibd_end()
		}

		if vui_hbox_scoped("menu_bar", {0,0, scrn_width, 30}) {
			_, menu_bar := _vui_peek_current_open_widget()
			menu_bar.layout.padding = {6,2,6,2}
			menu_bar.layout.spacing = 4
			_vuibd_draw_rect({color={0,0,0,120}})

			btn_rect := Rect{0,0,60,-1}
			if vui_button("menu_btn_file", btn_rect, "File").clicked {
				fmt.printf("file\n")
			}
			if vui_button("menu_btn_edit", btn_rect, "Edit").clicked {
				fmt.printf("edit\n")
			}
			if vui_button("menu_btn_locale", btn_rect, "本地化").clicked {
				fmt.printf("locale\n")
			}
			vui_space({0,0,-1,-1})

			if vui_button("menu_btn_end", btn_rect, "End").clicked {
				fmt.printf("end\n")
			}
		}



		if vui_vbox_scoped("box_test", {20, 140, 320, 400}) {
			_, box := _vui_peek_current_open_widget()
			box.layout.padding = {8,6,8,6}

			if vui_button("btn_elem1", {0,0, -1, 30}, "ELEM1").clicked {
				fmt.printf("you pressed on E1!\n")
			}
			vui_space({0,0,-1, 18})

			if vui_button("strange_line", {0,0,-1, 12}, "line").clicked {
				fmt.printf("just a line\n")
			}

			vui_space({0,0,-1, 18})

			if vui_hbox_scoped("line", {0,0, -1, 30}) {
				_, box := _vui_peek_current_open_widget()
				box.layout.padding = {8,6,8,6}
				box.layout.spacing = 8

				if vui_button("spacing_begin", {0,0, -35, -1}, "elema").clicked {
					fmt.printf("you pressed on EA!\n")
				}
				if vui_button("btn_elemb", {0,0, -20, 60}, "elemb").clicked {
					fmt.printf("you pressed on EB!\n")
				}
				if vui_button("spacing_end", {0,0, -10, -1}, "another fit").clicked {
					fmt.printf("you pressed on me!\n")
				}
			}
			if vui_button("do_something", {0,0,-1, -40}, "a flex button").clicked {
				fmt.printf("flex button\n")
			}
			if vui_hbox_scoped("btns", {0,0, -1, -1}) {
				_, box := _vui_peek_current_open_widget()
				box.layout.spacing = 4
				if vui_button("left", {0,0,-1,-1}, "LEFT").clicked {
					fmt.printf("left\n")
				}
				if vui_button("right", {0,0,20,-1}, "RIGHT").clicked {
					fmt.printf("right\n")
				}
			}
		}
	}
}

vui_button :: proc(ulabel: string, rect: Rect, text: string) -> VuiInteract {
	_vuibd_begin(vuid(ulabel), rect)
	draw_rect := _vuibd_draw_rect({
		color = {180,184,130, 255},
		round = 4,
		shadow_color = {0,0,0, 64},
		shadow_offset = {3,3},
		border_color = {200,200,200, 255},
		border_width = 1
	})
	draw_rect.box_hover.color = {200,204,150, 255}
	draw_rect.box_active.color = {240,235,240, 255}

	_vuibd_clickable()
	draw_text := _vuibd_draw_text({color={30,20,43,255}, size=ui_font_size, clip=true}, text)
	using draw_text
	// text_hover.size += 2
	text_hover.clip = false
	text_hover.shadow_offset = {2,2}
	text_hover.shadow_color = {255,255,255, 200}
	// text_active.size += 2
	text_active.clip = false
	return _vuibd_end()
}

@(deferred_none=_vuibd_end)
vui_vbox_scoped :: proc(label: string, rect: Rect) -> bool {
	_vuibd_begin(vuid(label), rect)
	layout := _vuibd_layout(.Vertical)
	layout.spacing = 4
	return true
}
@(deferred_none=_vuibd_end)
vui_hbox_scoped :: proc(label: string, rect: Rect) -> bool {
	_vuibd_begin(vuid(label), rect)
	layout := _vuibd_layout(.Horizontal)
	layout.spacing = 4
	return true
}

vui_space :: proc(rect: Rect) {
	_vuibd_begin(rand.uint64(), rect)
	_vuibd_end()
}
