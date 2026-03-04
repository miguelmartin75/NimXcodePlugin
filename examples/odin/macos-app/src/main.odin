#+build darwin

package main

import "base:runtime"
import "core:fmt"
import "core:slice"
import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"
import MTK "vendor:darwin/MetalKit"

WINDOW_DELEGATE_CLASS_NAME :: "OdinMetalExampleWindowDelegate"

Vertex :: struct {
	position: [2]f32,
	color:    [4]f32,
}

Uniforms :: struct {
	phase:        f32,
	aspect_ratio: f32,
}

App_State :: struct {
	device: ^MTL.Device,
	queue:  ^MTL.CommandQueue,

	library:  ^MTL.Library,
	pipeline: ^MTL.RenderPipelineState,

	view:   ^MTK.View,
	window: ^NS.Window,

	view_delegate:   ^MTK.ViewDelegate,
	window_delegate: ^NS.WindowDelegate,

	phase: f32,
}

TRIANGLE_VERTICES :: [3]Vertex{
	{{0.0, 0.62}, {0.96, 0.36, 0.28, 1.0}},
	{{-0.68, -0.48}, {0.22, 0.78, 0.97, 1.0}},
	{{0.68, -0.52}, {0.96, 0.87, 0.29, 1.0}},
}

release_ns_object :: proc(obj: ^NS.Object) {
	if obj != nil {
		obj->release()
	}
}

state_from_delegate :: proc(delegate: ^MTK.ViewDelegate) -> ^App_State {
	if delegate == nil || delegate.user_data == nil {
		return nil
	}
	return (^App_State)(delegate.user_data)
}

describe_error :: proc(err: ^NS.Error) -> string {
	if err == nil {
		return "unknown error"
	}
	desc := err->localizedDescription()
	if desc == nil {
		return "unknown error"
	}
	return desc->odinString()
}

destroy_app_state :: proc(state: ^App_State) {
	if state == nil {
		return
	}

	if state.view != nil {
		release_ns_object((^NS.Object)(state.view))
		state.view = nil
	}
	if state.window != nil {
		release_ns_object((^NS.Object)(state.window))
		state.window = nil
	}
	if state.window_delegate != nil {
		release_ns_object((^NS.Object)(state.window_delegate))
		state.window_delegate = nil
	}
	if state.pipeline != nil {
		release_ns_object((^NS.Object)(state.pipeline))
		state.pipeline = nil
	}
	if state.library != nil {
		release_ns_object((^NS.Object)(state.library))
		state.library = nil
	}
	if state.queue != nil {
		release_ns_object((^NS.Object)(state.queue))
		state.queue = nil
	}
	if state.device != nil {
		release_ns_object((^NS.Object)(state.device))
		state.device = nil
	}
	if state.view_delegate != nil {
		free(state.view_delegate)
		state.view_delegate = nil
	}

	free(state)
}

load_pipeline :: proc(state: ^App_State, view: ^MTK.View) -> bool {
	if state == nil || state.device == nil || view == nil {
		return false
	}

	bundle := NS.Bundle_mainBundle()
	if bundle == nil {
		fmt.println("error: main bundle is unavailable")
		return false
	}

	resource_path := bundle->resourcePath()
	if resource_path == nil {
		fmt.println("error: bundle resource path is unavailable")
		return false
	}

	metallib_path := resource_path->stringByAppendingString(NS.AT("/default.metallib"))
	library, library_err := state.device->newLibraryWithFile(metallib_path)
	if library == nil {
		fmt.println("error: failed to load Metal library:", describe_error(library_err))
		return false
	}
	state.library = library

	vertex_fn := library->newFunctionWithName(NS.AT("vertex_main"))
	fragment_fn := library->newFunctionWithName(NS.AT("fragment_main"))
	if vertex_fn == nil || fragment_fn == nil {
		fmt.println("error: failed to load shader functions from default.metallib")
		release_ns_object((^NS.Object)(vertex_fn))
		release_ns_object((^NS.Object)(fragment_fn))
		return false
	}
	defer release_ns_object((^NS.Object)(vertex_fn))
	defer release_ns_object((^NS.Object)(fragment_fn))

	pipeline_desc := MTL.RenderPipelineDescriptor.alloc()->init()
	defer release_ns_object((^NS.Object)(pipeline_desc))

	pipeline_desc->setLabel(NS.AT("Triangle Pipeline"))
	pipeline_desc->setVertexFunction(vertex_fn)
	pipeline_desc->setFragmentFunction(fragment_fn)
	pipeline_desc->colorAttachments()->object(0)->setPixelFormat(view->colorPixelFormat())

	pipeline, pipeline_err := state.device->newRenderPipelineState(pipeline_desc)
	if pipeline == nil {
		fmt.println("error: failed to create render pipeline:", describe_error(pipeline_err))
		return false
	}

	state.pipeline = pipeline
	return true
}

draw_in_mtk_view :: proc "c" (delegate: ^MTK.ViewDelegate, view: ^MTK.View) {
	context = runtime.default_context()

	state := state_from_delegate(delegate)
	if state == nil || state.queue == nil || state.pipeline == nil {
		return
	}

	render_pass := view->currentRenderPassDescriptor()
	drawable := view->currentDrawable()
	if render_pass == nil || drawable == nil {
		return
	}

	color_attachment := render_pass->colorAttachments()->object(0)
	color_attachment->setClearColor(MTL.ClearColor{0.08, 0.09, 0.13, 1.0})
	color_attachment->setLoadAction(.Clear)
	color_attachment->setStoreAction(.Store)

	drawable_size := view->drawableSize()
	aspect_ratio: f32 = 1.0
	if drawable_size.height > 0 {
		aspect_ratio = f32(drawable_size.width / drawable_size.height)
	}

	uniforms := [1]Uniforms{{
		phase = state.phase,
		aspect_ratio = aspect_ratio,
	}}
	vertices := TRIANGLE_VERTICES

	command_buffer := state.queue->commandBuffer()
	if command_buffer == nil {
		return
	}

	encoder := command_buffer->renderCommandEncoderWithDescriptor(render_pass)
	if encoder == nil {
		return
	}

	encoder->setRenderPipelineState(state.pipeline)
	encoder->setVertexBytes(slice.to_bytes(vertices[:]), 0)
	encoder->setVertexBytes(slice.to_bytes(uniforms[:]), 1)
	encoder->setFragmentBytes(slice.to_bytes(uniforms[:]), 1)
	encoder->drawPrimitives(.Triangle, 0, 3)
	(^MTL.CommandEncoder)(encoder)->endEncoding()

	command_buffer->presentDrawable((^MTL.Drawable)(drawable))
	command_buffer->commit()

	state.phase += 1.0 / 60.0
}

drawable_size_will_change :: proc "c" (delegate: ^MTK.ViewDelegate, view: ^MTK.View, size: NS.Size) {
	context = runtime.default_context()
	_ = delegate
	_ = view
	_ = size
}

make_window_delegate :: proc() -> ^NS.WindowDelegate {
	tpl := NS.WindowDelegateTemplate{}
	tpl.windowWillClose = proc(notification: ^NS.Notification) {
		context = runtime.default_context()
		_ = notification
		NS.Application_sharedApplication()->terminate(nil)
	}
	return NS.window_delegate_register_and_alloc(tpl, WINDOW_DELEGATE_CLASS_NAME, nil)
}

run_macos_app :: proc() {
	pool := NS.AutoreleasePool.alloc()->init()
	defer pool->drain()

	device := MTL.CreateSystemDefaultDevice()
	if device == nil {
		fmt.println("error: Metal is unavailable on this machine")
		return
	}

	state := new(App_State)
	state^ = {
		device = device,
		queue = device->newCommandQueue(),
	}

	if state.queue == nil {
		fmt.println("error: failed to create a Metal command queue")
		destroy_app_state(state)
		return
	}

	app := NS.Application_sharedApplication()
	_ = app->setActivationPolicy(.Regular)

	frame := NS.Rect{
		x = 0,
		y = 0,
		width = 960,
		height = 640,
	}

	view := MTK.View_initWithFrame(MTK.View.alloc(), frame, device)
	view->setColorPixelFormat(.BGRA8Unorm)
	view->setClearColor(MTL.ClearColor{0.08, 0.09, 0.13, 1.0})
	view->setPreferredFramesPerSecond(60)
	view->setEnableSetNeedsDisplay(false)
	view->setPaused(false)
	state.view = view

	if !load_pipeline(state, view) {
		destroy_app_state(state)
		return
	}

	state.view_delegate = new(MTK.ViewDelegate)
	state.view_delegate^ = {
		drawInMTKView = draw_in_mtk_view,
		drawableSizeWillChange = drawable_size_will_change,
		user_data = state,
	}
	view->setDelegate(state.view_delegate)

	window_style := NS.WindowStyleMask{.Titled, .Closable, .Miniaturizable, .Resizable}
	window := NS.Window.alloc()->initWithContentRect(frame, window_style, .Buffered, false)
	window->setTitle(NS.AT("Odin Metal Example"))
	window->setContentView((^NS.View)(view))
	window->center()
	window->makeKeyAndOrderFront(nil)
	state.window = window

	state.window_delegate = make_window_delegate()
	if state.window_delegate != nil {
		window->setDelegate(state.window_delegate)
	}

	app->activateIgnoringOtherApps(true)
	app->run()

	destroy_app_state(state)
}

main :: proc() {
	run_macos_app()
}
