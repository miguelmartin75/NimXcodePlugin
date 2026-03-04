package main

import "core:c"
import "core:fmt"
import "core:os"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"
import CA "vendor:darwin/QuartzCore"
import SDL "vendor:sdl3"

sdl_error_string :: proc() -> string {
	err := SDL.GetError()
	if err == nil {
		return "unknown SDL error"
	}

	return string(err)
}

ns_error_string :: proc(err: ^NS.Error) -> string {
	if err == nil {
		return "unknown Metal error"
	}

	return err->localizedDescription()->odinString()
}

errorf :: proc(format: string, args: ..any) -> string {
	return fmt.aprintf(format, ..args)
}

load_shader_library :: proc(device: ^MTL.Device) -> (^MTL.Library, string) {
	default_library_error := ""

	bundle := NS.Bundle.mainBundle()
	if bundle != nil {
		library, err := device->newDefaultLibraryWithBundle(bundle)
		if library != nil {
			return library, ""
		}
		if err != nil {
			default_library_error = ns_error_string(err)
		}
	}

	base_path := SDL.GetBasePath()
	if base_path == nil {
		if default_library_error != "" {
			return nil, default_library_error
		}
		return nil, errorf("SDL_GetBasePath failed: %s", sdl_error_string())
	}

	shader_path := errorf("%sdefault.metallib", string(base_path))
	shader_path_ns := NS.alloc(NS.String)
	shader_path_ns = shader_path_ns->initWithOdinString(shader_path)
	defer shader_path_ns->release()

	library, err := device->newLibraryWithFile(shader_path_ns)
	if library != nil {
		return library, ""
	}

	file_error := ns_error_string(err)
	if default_library_error != "" {
		return nil, errorf("%s; fallback to %s failed: %s", default_library_error, shader_path, file_error)
	}
	return nil, file_error
}

run :: proc() -> string {
	if !SDL.Init(SDL.INIT_VIDEO) {
		return errorf("SDL_Init failed: %s", sdl_error_string())
	}
	defer SDL.Quit()

	window := SDL.CreateWindow(
		"SDL3 Metal",
		854,
		480,
		SDL.WINDOW_HIGH_PIXEL_DENSITY | SDL.WINDOW_RESIZABLE | SDL.WINDOW_METAL,
	)
	if window == nil {
		return errorf("SDL_CreateWindow failed: %s", sdl_error_string())
	}
	defer SDL.DestroyWindow(window)

	metal_view := SDL.Metal_CreateView(window)
	if rawptr(metal_view) == nil {
		return errorf("SDL_Metal_CreateView failed: %s", sdl_error_string())
	}
	defer SDL.Metal_DestroyView(metal_view)

	swapchain := (^CA.MetalLayer)(SDL.Metal_GetLayer(metal_view))
	if swapchain == nil {
		return errorf("SDL_Metal_GetLayer failed: %s", sdl_error_string())
	}

	device := MTL.CreateSystemDefaultDevice()
	if device == nil {
		return "MTLCreateSystemDefaultDevice returned nil"
	}

	swapchain->setDevice(device)
	swapchain->setPixelFormat(.BGRA8Unorm_sRGB)
	swapchain->setFramebufferOnly(true)

	command_queue := device->newCommandQueue()
	if command_queue == nil {
		return "device->newCommandQueue returned nil"
	}

	program_library, err := load_shader_library(device)
	if program_library == nil {
		return errorf("failed to load Metal shader library: %s", err)
	}

	vertex_program := program_library->newFunctionWithName(NS.AT("vertex_main"))
	fragment_program := program_library->newFunctionWithName(NS.AT("fragment_main"))
	if vertex_program == nil || fragment_program == nil {
		return "failed to load shader entry points from the Metal library"
	}

	pipeline_state_descriptor := NS.new(MTL.RenderPipelineDescriptor)
	pipeline_state_descriptor->colorAttachments()->object(0)->setPixelFormat(.BGRA8Unorm_sRGB)
	pipeline_state_descriptor->setVertexFunction(vertex_program)
	pipeline_state_descriptor->setFragmentFunction(fragment_program)

	pipeline_state, pipeline_err := device->newRenderPipelineState(pipeline_state_descriptor)
	if pipeline_state == nil {
		return errorf("failed to create Metal pipeline state: %s", ns_error_string(pipeline_err))
	}

	positions := [?][4]f32{
		{ 0.0,  0.5, 0.0, 1.0},
		{-0.5, -0.5, 0.0, 1.0},
		{ 0.5, -0.5, 0.0, 1.0},
	}
	colors := [?][4]f32{
		{1.0, 0.0, 0.0, 1.0},
		{0.0, 1.0, 0.0, 1.0},
		{0.0, 0.0, 1.0, 1.0},
	}

	position_buffer := device->newBufferWithSlice(positions[:], {})
	color_buffer := device->newBufferWithSlice(colors[:], {})
	if position_buffer == nil || color_buffer == nil {
		return "failed to create Metal vertex buffers"
	}

	window_id := SDL.GetWindowID(window)

	for quit := false; !quit; {
		for event: SDL.Event; SDL.PollEvent(&event); {
			#partial switch event.type {
			case .QUIT:
				quit = true
			case .WINDOW_CLOSE_REQUESTED:
				if event.window.windowID == window_id {
					quit = true
				}
			case .KEY_DOWN:
				if event.key.key == SDL.K_ESCAPE {
					quit = true
				}
			}
		}

		NS.scoped_autoreleasepool()

		drawable := swapchain->nextDrawable()
		if drawable == nil {
			continue
		}

		pass := MTL.RenderPassDescriptor.renderPassDescriptor()
		color_attachment := pass->colorAttachments()->object(0)
		color_attachment->setClearColor(MTL.ClearColor{0.25, 0.5, 1.0, 1.0})
		color_attachment->setLoadAction(.Clear)
		color_attachment->setStoreAction(.Store)
		color_attachment->setTexture(drawable->texture())

		command_buffer := command_queue->commandBuffer()
		render_encoder := command_buffer->renderCommandEncoderWithDescriptor(pass)

		render_encoder->setRenderPipelineState(pipeline_state)
		render_encoder->setVertexBuffer(position_buffer, 0, 0)
		render_encoder->setVertexBuffer(color_buffer, 0, 1)
		render_encoder->drawPrimitives(.Triangle, 0, 3)
		render_encoder->endEncoding()

		command_buffer->presentDrawable(drawable)
		command_buffer->commit()
	}

	return ""
}

main :: proc() {
	if err := run(); err != "" {
		fmt.eprintln(err)
		os.exit(1)
	}
}
