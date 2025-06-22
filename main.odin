package main

import "core:fmt"
import rl "vendor:raylib"
import nvg "vendor:nanovg"

vg : ^nvg.Context

fontid_default : int

main :: proc() {
	rl.SetTargetFPS(60)
	rl.InitWindow(800, 600, "Tabro"); defer rl.CloseWindow()
	vg = draw_init(); defer draw_release(vg)

	// fontid_default = nvg.CreateFont(vg, "xwwk", "LXGWWenKai-Regular.ttf")
	fontid_default = nvg.CreateFont(vg, "xwwk", "IosevkaTermSlabNerdFontMono-Regular.ttf")

	vui_init(); defer vui_release()

	offset := rl.Vector2{0,0}
	frame :rl.Rectangle= {10,10, 400, 30}

	for !rl.WindowShouldClose() {
		// update
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

		nvg.BeginFrame(vg, 800, 600, 1.0)
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
			{0,0, cast(f32)rl.GetScreenWidth(), cast(f32)rl.GetScreenHeight()}
		)
		defer vui_end()

		{
			_vuibd_begin("background", {20, 140, 320, 400})
			_vuibd_draw_rect({32, 32, 12, 255}, {32, 32, 12, 255}, 2)
			_vuibd_end()
		}
		if vui_vbox_scoped("box_test", {20, 140, 320, 400}) {
			_, box := _vui_peek_current_open_widget()
			box.layout.padding = {8,6,8,6}

			if vui_button("btn_elem1", {0,0, -1, 30}, "ELEM1").pressed {
				fmt.printf("you pressed on E1!\n")
			}
			if vui_hbox_scoped("line", {0,0, -1, 30}) {
				_, box := _vui_peek_current_open_widget()
				box.layout.padding = {8,6,8,6}

				if vui_button("spacing_begin", {0,0, -35, -1}, "elema").pressed {
					fmt.printf("you pressed on EA!\n")
				}
				if vui_button("btn_elemb", {0,0, -20, 60}, "elemb").pressed {
					fmt.printf("you pressed on EB!\n")
				}
				if vui_button("spacing_end", {0,0, -10, -1}, "another fit").pressed {
					fmt.printf("you pressed on me!\n")
				}
			}
			if vui_button("do_something", {0,0,-1, -40}, "a flex button").pressed {
				fmt.printf("flex button\n")
			}
			if vui_hbox_scoped("btns", {0,0, -1, -1}) {
				_, box := _vui_peek_current_open_widget()
				box.layout.spacing = 4
				if vui_button("left", {0,0,-1,-1}, "LEFT").pressed {
					fmt.printf("left\n")
				}
				if vui_button("right", {0,0,20,-1}, "RIGHT").pressed {
					fmt.printf("right\n")
				}
			}
		}
	}
}

vui_button :: proc(ulabel: string, rect: Rect, text: string) -> VuiInteract {
	_vuibd_begin(ulabel, rect)
	draw_rect := _vuibd_draw_rect({128, 120, 98, 255}, {138, 130, 110, 255}, 4.0)
	draw_rect.shadow_color = {0,0,0, 64}
	draw_rect.shadow_offset = {3,3}
	
	draw_rect.border_color = {200,200,200, 255}
	draw_rect.border_width = 1
	_vuibd_clickable()
	draw_text := _vuibd_draw_text({30,20,43,255}, text, 28)
	// draw_text.clip = true
	return _vuibd_end()
}

@(deferred_none=_vuibd_end)
vui_vbox_scoped :: proc(ulabel: string, rect: Rect) -> bool {
	_vuibd_begin(ulabel, rect)
	draw_rect := _vuibd_draw_rect({}, {})
	// draw_rect.border_color = {0,100,0, 255}
	// draw_rect.border_width = 1
	layout := _vuibd_layout(.Vertical)
	layout.spacing = 4
	return true
}
@(deferred_none=_vuibd_end)
vui_hbox_scoped :: proc(ulabel: string, rect: Rect) -> bool {
	_vuibd_begin(ulabel, rect)
	draw_rect := _vuibd_draw_rect({}, {})
	// draw_rect.border_color = {0,100,0, 255}
	// draw_rect.border_width = 1
	layout := _vuibd_layout(.Horizontal)
	layout.spacing = 4
	return true
}
