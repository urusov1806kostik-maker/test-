package dev.shadowvisuals.render;

import com.mojang.blaze3d.pipeline.RenderPipeline;
import com.mojang.blaze3d.platform.DepthTestFunction;
import com.mojang.blaze3d.systems.RenderSystem;
import com.mojang.blaze3d.vertex.VertexFormat;
import com.mojang.blaze3d.vertex.VertexFormatElement;

import net.minecraft.client.renderer.RenderPipelines;
import net.minecraft.resources.Identifier;

import dev.shadowvisuals.core.ClientInfo;
import dev.shadowvisuals.core.Log;

/**
 * Render pipelines owned by Shadow Visuals. Custom shaders are validated after every resource reload; if a
 * driver rejects them, rendering falls back to vanilla primitives instead of drawing nothing or crashing.
 */
public final class ShadowPipelines {
	/** Position, color, local position (UV0), half size (UV1) and radius/mode (UV2). Only vanilla elements. */
	public static final VertexFormat SHAPE_FORMAT = VertexFormat.builder()
		.add("Position", VertexFormatElement.POSITION)
		.add("Color", VertexFormatElement.COLOR)
		.add("UV0", VertexFormatElement.UV0)
		.add("UV1", VertexFormatElement.UV1)
		.add("UV2", VertexFormatElement.UV2)
		.build();

	public static final RenderPipeline UI_SHAPE = RenderPipeline.builder(RenderPipelines.GUI_SNIPPET)
		.withLocation(id("pipeline/ui_shape"))
		.withVertexShader(id("core/ui_shape"))
		.withFragmentShader(id("core/ui_shape"))
		.withVertexFormat(SHAPE_FORMAT, VertexFormat.Mode.QUADS)
		.build();

	public static final RenderPipeline SDF_TEXT = RenderPipeline.builder(RenderPipelines.GUI_TEXTURED_SNIPPET)
		.withLocation(id("pipeline/sdf_text"))
		.withVertexShader(id("core/sdf_text"))
		.withFragmentShader(id("core/sdf_text"))
		.build();

	/** World lines drawn on top of terrain (ESP, waypoints). */
	public static final RenderPipeline WORLD_LINES_SEE_THROUGH = RenderPipeline.builder(RenderPipelines.LINES_SNIPPET)
		.withLocation(id("pipeline/world_lines_see_through"))
		.withDepthTestFunction(DepthTestFunction.NO_DEPTH_TEST)
		.withDepthWrite(false)
		.build();

	/** Translucent world quads, depth tested (jump circles, trails, block overlay). */
	public static final RenderPipeline WORLD_QUADS = RenderPipeline.builder(RenderPipelines.DEBUG_FILLED_SNIPPET)
		.withLocation(id("pipeline/world_quads"))
		.withCull(false)
		.build();

	/** Translucent world quads visible through walls (ESP fills). */
	public static final RenderPipeline WORLD_QUADS_SEE_THROUGH = RenderPipeline.builder(RenderPipelines.DEBUG_FILLED_SNIPPET)
		.withLocation(id("pipeline/world_quads_see_through"))
		.withCull(false)
		.withDepthTestFunction(DepthTestFunction.NO_DEPTH_TEST)
		.build();

	/** Distance-field text in the world (3D labels): same shader as GUI text, world depth, no culling. */
	public static final RenderPipeline WORLD_SDF_TEXT = RenderPipeline.builder(RenderPipelines.MATRICES_PROJECTION_SNIPPET)
		.withLocation(id("pipeline/world_sdf_text"))
		.withVertexShader(id("core/sdf_text"))
		.withFragmentShader(id("core/sdf_text"))
		.withSampler("Sampler0")
		.withBlend(com.mojang.blaze3d.pipeline.BlendFunction.TRANSLUCENT)
		.withVertexFormat(com.mojang.blaze3d.vertex.DefaultVertexFormat.POSITION_TEX_COLOR, com.mojang.blaze3d.vertex.VertexFormat.Mode.QUADS)
		.withCull(false)
		.withDepthWrite(false)
		.build();

	/** {@link #WORLD_SDF_TEXT} drawn on top of terrain. */
	public static final RenderPipeline WORLD_SDF_TEXT_SEE_THROUGH = RenderPipeline.builder(RenderPipelines.MATRICES_PROJECTION_SNIPPET)
		.withLocation(id("pipeline/world_sdf_text_see_through"))
		.withVertexShader(id("core/sdf_text"))
		.withFragmentShader(id("core/sdf_text"))
		.withSampler("Sampler0")
		.withBlend(com.mojang.blaze3d.pipeline.BlendFunction.TRANSLUCENT)
		.withVertexFormat(com.mojang.blaze3d.vertex.DefaultVertexFormat.POSITION_TEX_COLOR, com.mojang.blaze3d.vertex.VertexFormat.Mode.QUADS)
		.withCull(false)
		.withDepthWrite(false)
		.withDepthTestFunction(DepthTestFunction.NO_DEPTH_TEST)
		.build();

	private static boolean shapesAvailable = true;
	private static boolean textAvailable = true;
	private static boolean worldTextAvailable = true;
	private static boolean validationPending = true;

	private ShadowPipelines() {
	}

	private static Identifier id(String path) {
		return Identifier.fromNamespaceAndPath(ClientInfo.MOD_ID, path);
	}

	/** Requests re-validation after a resource reload (shader sources may have changed). */
	public static void invalidate() {
		validationPending = true;
	}

	/**
	 * Compiles the custom GUI pipelines once shaders are loaded (no loading overlay active). Called at the
	 * start of every 2D frame; after the first successful check it is a single boolean test.
	 */
	public static void ensureValidated() {
		if (!validationPending || net.minecraft.client.Minecraft.getInstance().getOverlay() != null) {
			return;
		}
		validationPending = false;
		shapesAvailable = compiles(UI_SHAPE);
		textAvailable = compiles(SDF_TEXT);
		worldTextAvailable = textAvailable && compiles(WORLD_SDF_TEXT) && compiles(WORLD_SDF_TEXT_SEE_THROUGH);
	}

	private static boolean compiles(RenderPipeline pipeline) {
		try {
			boolean valid = RenderSystem.getDevice().precompilePipeline(pipeline).isValid();
			if (!valid) {
				Log.errorOnce("pipeline:" + pipeline.getLocation(),
					"Shader pipeline {} failed to compile; using the vanilla fallback", pipeline.getLocation());
			}
			return valid;
		} catch (RuntimeException e) {
			Log.errorOnce("pipeline:" + pipeline.getLocation(), "Could not compile {}", pipeline.getLocation(), e);
			return false;
		}
	}

	public static boolean shapesAvailable() {
		return shapesAvailable;
	}

	public static boolean textAvailable() {
		return textAvailable;
	}

	/** Whether the custom font can be drawn in the world; checked like the GUI pipelines. */
	public static boolean worldTextAvailable() {
		return worldTextAvailable && !validationPending;
	}
}
