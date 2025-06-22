package main

import win32 "core:sys/windows"

import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"
import gl "vendor:OpenGL"
import nvg "vendor:nanovg"
import nvgl "vendor:nanovg/gl"


draw_init :: proc() -> ^nvg.Context {
	gl.load_up_to(4,5, win32.gl_set_proc_address)
	return nvgl.Create({.ANTI_ALIAS, .STENCIL_STROKES})
}

draw_release :: proc(vg: ^nvg.Context) {
	nvgl.Destroy(vg)
}
