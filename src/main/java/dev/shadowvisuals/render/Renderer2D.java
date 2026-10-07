package dev.shadowvisuals.render;

import java.util.List;

import org.joml.Matrix3x2f;
import org.joml.Matrix3x2fStack;

import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.navigation.ScreenRectangle;
import net.minecraft.client.renderer.RenderPipelines;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.Identifier;
import net.minecraft.world.item.ItemStack;

import dev.shadowvisuals.render.font.FontManager;
import dev.shadowvisuals.render.font.TextLayout;
import dev.shadowvisuals.render.font.TextQuads;
import dev.shadowvisuals.render.state.SdfTextRenderState;
import dev.shadowvisuals.render.state.ShapeRenderState;
import dev.shadowvisuals.util.ColorUtil;

/**
 * The single 2D drawing API of the client (GUI, HUD, overlays). Wraps the current {@link GuiGraphics} and
 * submits retained render states, so no GL state is touched directly and vanilla rendering is never
 * disturbed. Shapes use the analytic {@code ui_shape} shader; when unavailable they degrade to plain fills.
 */
public final class Renderer2D {
	public enum Align {
		LEFT,
		CENTER,
		RIGHT
	}

	private static final String ELLIPSIS = "…";

	private final FontManager fonts;
	private final float[] alphaStack = new float[16];
	private int alphaDepth;
	private float alpha = 1f;
	private GuiGraphics graphics;

	public Renderer2D(FontManager fonts) {
		this.fonts = fonts;
	}

	public FontManager fonts() {
		return fonts;
	}

	/** Binds the frame's graphics context. Must be called before drawing. */
	public Renderer2D begin(GuiGraphics context) {
		this.graphics = context;
		this.alpha = 1f;
		this.alphaDepth = 0;
		ShadowPipelines.ensureValidated();
		fonts.uploadPending();
		return this;
	}

	/** Multiplies the opacity of everything drawn until the matching {@link #popAlpha}. */
	public void pushAlpha(float factor) {
		if (alphaDepth < alphaStack.length) {
			alphaStack[alphaDepth] = alpha;
		}
		alphaDepth++;
		alpha *= Math.max(0f, Math.min(1f, factor));
	}

	public void popAlpha() {
		if (alphaDepth > 0) {
			alphaDepth--;
			alpha = alphaDepth < alphaStack.length ? alphaStack[alphaDepth] : alpha;
		}
	}

	public float alpha() {
		return alpha;
	}

	private int applyAlpha(int color) {
		return alpha >= 1f ? color : ColorUtil.fade(color, alpha);
	}

	public GuiGraphics graphics() {
		return graphics;
	}

	public Matrix3x2fStack pose() {
		return graphics.pose();
	}

	private ScreenRectangle scissor() {
		return graphics.scissorStack.peek();
	}

	// ---------------------------------------------------------------- transforms & clipping

	public void push() {
		graphics.pose().pushMatrix();
	}

	public void pop() {
		graphics.pose().popMatrix();
	}

	public void translate(float x, float y) {
		graphics.pose().translate(x, y);
	}

	public void scale(float factor) {
		graphics.pose().scale(factor, factor);
	}

	/** Scales around a pivot (used for open/close and pop animations). */
	public void scaleAround(float factor, float pivotX, float pivotY) {
		Matrix3x2fStack pose = graphics.pose();
		pose.translate(pivotX, pivotY);
		pose.scale(factor, factor);
		pose.translate(-pivotX, -pivotY);
	}

	/** Restricts drawing to a rectangle (intersected with any active clip). Always pair with {@link #popClip}. */
	public void pushClip(float x, float y, float width, float height) {
		graphics.enableScissor((int) Math.floor(x), (int) Math.floor(y), (int) Math.ceil(x + width), (int) Math.ceil(y + height));
	}

	public void popClip() {
		graphics.disableScissor();
	}

	// ---------------------------------------------------------------- shapes

	public void rect(float x, float y, float width, float height, int color) {
		rounded(x, y, width, height, 0, color);
	}

	public void rounded(float x, float y, float width, float height, float radius, int color) {
		rounded(x, y, width, height, radius, color, color, color, color);
	}

	/** Rounded rectangle with per-corner colors (top-left, top-right, bottom-right, bottom-left). */
	public void rounded(float x, float y, float width, float height, float radius,
		int topLeft, int topRight, int bottomRight, int bottomLeft) {
		if (width <= 0 || height <= 0 || allTransparent(topLeft, topRight, bottomRight, bottomLeft)) {
			return;
		}
		if (!ShadowPipelines.shapesAvailable()) {
			graphics.fillGradient(Math.round(x), Math.round(y), Math.round(x + width), Math.round(y + height), applyAlpha(topLeft), applyAlpha(bottomLeft));
			return;
		}
		submit(x, y, width, height, 0, topLeft, bottomLeft, bottomRight, topRight, radius, 0);
	}

	public void gradientHorizontal(float x, float y, float width, float height, float radius, int left, int right) {
		rounded(x, y, width, height, radius, left, right, right, left);
	}

	public void gradientVertical(float x, float y, float width, float height, float radius, int top, int bottom) {
		rounded(x, y, width, height, radius, top, top, bottom, bottom);
	}

	public void outline(float x, float y, float width, float height, float radius, float thickness, int color) {
		if (width <= 0 || height <= 0 || ColorUtil.alpha(color) == 0 || thickness <= 0) {
			return;
		}
		if (!ShadowPipelines.shapesAvailable()) {
			int x0 = Math.round(x);
			int y0 = Math.round(y);
			int x1 = Math.round(x + width);
			int y1 = Math.round(y + height);
			int t = Math.max(1, Math.round(thickness));
			color = applyAlpha(color);
			graphics.fill(x0, y0, x1, y0 + t, color);
			graphics.fill(x0, y1 - t, x1, y1, color);
			graphics.fill(x0, y0 + t, x0 + t, y1 - t, color);
			graphics.fill(x1 - t, y0 + t, x1, y1 - t, color);
			return;
		}
		submit(x, y, width, height, 0, color, color, color, color, radius, thickness);
	}

	/** Soft drop shadow behind a rounded rectangle; {@code softness} is the blur reach in GUI units. */
	public void shadow(float x, float y, float width, float height, float radius, float softness, int color) {
		if (width <= 0 || height <= 0 || softness <= 0 || ColorUtil.alpha(color) == 0 || !ShadowPipelines.shapesAvailable()) {
			return;
		}
		submit(x, y, width, height, softness, color, color, color, color, radius, -softness);
	}

	/** Shadow, fill and hairline border in one call: the standard Shadow Visuals surface. */
	public void surface(float x, float y, float width, float height, float radius, int fill, int border, int shadowColor, float shadowSoftness) {
		if (shadowSoftness > 0) {
			shadow(x, y + 1, width, height, radius, shadowSoftness, shadowColor);
		}
		rounded(x, y, width, height, radius, fill);
		if (ColorUtil.alpha(border) > 0) {
			outline(x, y, width, height, radius, 1, border);
		}
	}

	public void circle(float centerX, float centerY, float radius, int color) {
		rounded(centerX - radius, centerY - radius, radius * 2, radius * 2, radius, color);
	}

	public void ring(float centerX, float centerY, float radius, float thickness, int color) {
		outline(centerX - radius, centerY - radius, radius * 2, radius * 2, radius, thickness, color);
	}

	/** Anti-aliased line with round caps, drawn as a rotated capsule. */
	public void line(float x1, float y1, float x2, float y2, float thickness, int color) {
		float dx = x2 - x1;
		float dy = y2 - y1;
		float length = (float) Math.sqrt(dx * dx + dy * dy);
		if (length < 1e-3f) {
			return;
		}
		Matrix3x2fStack pose = graphics.pose();
		pose.pushMatrix();
		pose.translate(x1, y1);
		pose.rotate((float) Math.atan2(dy, dx));
		float half = thickness * 0.5f;
		rounded(-half, -half, length + thickness, thickness, half, color);
		pose.popMatrix();
	}

	/**
	 * Filled polygon as a fan around {@code (centerX, centerY)}; {@code ring} holds x/y pairs. The center must
	 * see every edge (true for stars, arrows and convex shapes).
	 */
	public void fan(float centerX, float centerY, float[] ring, int color) {
		if (ring.length < 6 || ColorUtil.alpha(color) == 0) {
			return;
		}
		graphics.guiRenderState.submitGuiElement(dev.shadowvisuals.render.state.PolygonRenderState.create(
			new Matrix3x2f(graphics.pose()), centerX, centerY, ring, applyAlpha(color), scissor()));
	}

	/** Anti-aliased closed or open polyline through x/y pairs. */
	public void polyline(float[] points, float thickness, int color, boolean closed) {
		int count = points.length / 2;
		for (int i = 0; i + 1 < count; i++) {
			line(points[i * 2], points[i * 2 + 1], points[i * 2 + 2], points[i * 2 + 3], thickness, color);
		}
		if (closed && count > 2) {
			line(points[count * 2 - 2], points[count * 2 - 1], points[0], points[1], thickness, color);
		}
	}

	private void submit(float x, float y, float width, float height, float expand,
		int topLeft, int bottomLeft, int bottomRight, int topRight, float radius, float mode) {
		graphics.guiRenderState.submitGuiElement(ShapeRenderState.create(
			new Matrix3x2f(graphics.pose()), x, y, x + width, y + height, expand,
			applyAlpha(topLeft), applyAlpha(bottomLeft), applyAlpha(bottomRight), applyAlpha(topRight), radius, mode, scissor()));
	}

	private static boolean allTransparent(int a, int b, int c, int d) {
		return ((a | b | c | d) >>> 24) == 0;
	}

	// ---------------------------------------------------------------- text

	public float textWidth(String text, float size) {
		return fonts.width(text, size, FontManager.Weight.MEDIUM);
	}

	public float textWidth(String text, float size, FontManager.Weight weight) {
		return fonts.width(text, size, weight);
	}

	public float lineHeight(float size) {
		return fonts.lineHeight(size);
	}

	/** Draws text with its top-left corner at {@code (x, y)}. */
	public void text(String text, float x, float y, float size, int color) {
		text(text, x, y, size, color, FontManager.Weight.MEDIUM, false);
	}

	public void text(String text, float x, float y, float size, int color, FontManager.Weight weight, boolean shadow) {
		color = applyAlpha(color);
		if (text == null || text.isEmpty() || ColorUtil.alpha(color) == 0) {
			return;
		}
		TextLayout layout = fonts.layout(text, weight);
		if (layout == null || !layout.complete()) {
			vanillaText(text, x, y, size, color, shadow);
			return;
		}
		if (shadow) {
			submitText(layout, x + size * 0.08f, y + size * 0.08f, size, ColorUtil.fade(0xFF000000, ColorUtil.alpha(color) / 255f * 0.55f));
		}
		submitText(layout, x, y, size, color);
	}

	private void submitText(TextLayout layout, float x, float y, float size, int color) {
		Matrix3x2f pose = new Matrix3x2f(graphics.pose());
		ScreenRectangle scissor = scissor();
		float lineHeight = fonts.lineHeight(size);
		ScreenRectangle area = new ScreenRectangle((int) Math.floor(x - size * 0.2f), (int) Math.floor(y - size * 0.2f),
			(int) Math.ceil(layout.width() * size + size * 0.6f), (int) Math.ceil(lineHeight + size * 0.5f)).transformMaxBounds(pose);
		ScreenRectangle bounds = scissor != null ? scissor.intersection(area) : area;
		List<TextQuads.Page> pages = TextQuads.pages(layout);
		for (TextQuads.Page page : pages) {
			graphics.guiRenderState.submitGuiElement(new SdfTextRenderState(pose, layout, page.atlas(), page.textureSetup(),
				x, y, size, color, scissor, bounds));
		}
	}

	private void vanillaText(String text, float x, float y, float size, int color, boolean shadow) {
		float scale = fonts.vanillaScale(size);
		float offset = (fonts.ascenderEm() - fonts.capHeightEm()) * size;
		Matrix3x2fStack pose = graphics.pose();
		pose.pushMatrix();
		pose.translate(x, y + offset);
		pose.scale(scale, scale);
		graphics.drawString(Minecraft.getInstance().font, text, 0, 0, color, shadow);
		pose.popMatrix();
	}

	/** Draws server-provided text (formatting, colors, fonts preserved) with the vanilla renderer. */
	public void component(Component text, float x, float y, float scale, int color, boolean shadow) {
		color = applyAlpha(color);
		if (ColorUtil.alpha(color) == 0) {
			return;
		}
		Matrix3x2fStack pose = graphics.pose();
		pose.pushMatrix();
		pose.translate(x, y);
		pose.scale(scale, scale);
		graphics.drawString(Minecraft.getInstance().font, text, 0, 0, color, shadow);
		pose.popMatrix();
	}

	public void text(String text, float x, float y, float size, int color, Align align) {
		text(text, x, y, size, color, FontManager.Weight.MEDIUM, align);
	}

	public void text(String text, float x, float y, float size, int color, FontManager.Weight weight, Align align) {
		float width = align == Align.LEFT ? 0 : fonts.width(text, size, weight);
		float drawX = switch (align) {
			case LEFT -> x;
			case CENTER -> x - width / 2f;
			case RIGHT -> x - width;
		};
		text(text, drawX, y, size, color, weight, false);
	}

	/** Draws text vertically centered on {@code centerY} (based on capital height, not line height). */
	public void textMiddle(String text, float x, float centerY, float size, int color, FontManager.Weight weight, Align align) {
		text(text, x, centerY - fonts.visualCenter(size), size, color, weight, align);
	}

	public void textMiddle(String text, float x, float centerY, float size, int color) {
		textMiddle(text, x, centerY, size, color, FontManager.Weight.MEDIUM, Align.LEFT);
	}

	/** Shortens {@code text} with an ellipsis so it fits in {@code maxWidth}. */
	public String ellipsize(String text, float size, FontManager.Weight weight, float maxWidth) {
		if (text == null || fonts.width(text, size, weight) <= maxWidth) {
			return text;
		}
		float ellipsis = fonts.width(ELLIPSIS, size, weight);
		int low = 0;
		int high = text.length();
		while (low < high) {
			int mid = (low + high + 1) >>> 1;
			if (fonts.width(text.substring(0, mid), size, weight) + ellipsis <= maxWidth) {
				low = mid;
			} else {
				high = mid - 1;
			}
		}
		return low <= 0 ? ELLIPSIS : text.substring(0, low).stripTrailing() + ELLIPSIS;
	}

	/** Splits text into lines no wider than {@code maxWidth} (word wrap, long words are broken). */
	public List<String> wrap(String text, float size, float maxWidth) {
		java.util.ArrayList<String> lines = new java.util.ArrayList<>();
		for (String paragraph : text.split("\n", -1)) {
			StringBuilder line = new StringBuilder();
			for (String word : paragraph.split(" ")) {
				String candidate = line.isEmpty() ? word : line + " " + word;
				if (textWidth(candidate, size) <= maxWidth) {
					line.setLength(0);
					line.append(candidate);
					continue;
				}
				if (!line.isEmpty()) {
					lines.add(line.toString());
					line.setLength(0);
				}
				String rest = word;
				while (textWidth(rest, size) > maxWidth && rest.length() > 1) {
					int cut = rest.length() - 1;
					while (cut > 1 && textWidth(rest.substring(0, cut), size) > maxWidth) {
						cut--;
					}
					lines.add(rest.substring(0, cut));
					rest = rest.substring(cut);
				}
				line.append(rest);
			}
			lines.add(line.toString());
		}
		return lines;
	}

	// ---------------------------------------------------------------- items & textures

	/** Renders an item icon scaled to {@code size} GUI units (vanilla icons are 16). */
	public void item(ItemStack stack, float x, float y, float size) {
		if (stack == null || stack.isEmpty() || alpha < 0.35f) {
			return;
		}
		Matrix3x2fStack pose = graphics.pose();
		pose.pushMatrix();
		pose.translate(x, y);
		pose.scale(size / 16f, size / 16f);
		graphics.renderItem(stack, 0, 0);
		pose.popMatrix();
	}

	/** Item icon plus the vanilla count/durability overlay. */
	public void itemWithOverlay(ItemStack stack, float x, float y, float size) {
		if (stack == null || stack.isEmpty() || alpha < 0.35f) {
			return;
		}
		Matrix3x2fStack pose = graphics.pose();
		pose.pushMatrix();
		pose.translate(x, y);
		pose.scale(size / 16f, size / 16f);
		graphics.renderItem(stack, 0, 0);
		graphics.renderItemDecorations(Minecraft.getInstance().font, stack, 0, 0);
		pose.popMatrix();
	}

	/** Player head (face + hat layer) from a skin, scaled to {@code size}. */
	public void face(net.minecraft.world.entity.player.PlayerSkin skin, float x, float y, float size) {
		if (skin == null || alpha < 0.05f) {
			return;
		}
		Matrix3x2fStack pose = graphics.pose();
		pose.pushMatrix();
		pose.translate(x, y);
		pose.scale(size / 8f, size / 8f);
		net.minecraft.client.gui.components.PlayerFaceRenderer.draw(graphics, skin, 0, 0, 8, applyAlpha(0xFFFFFFFF));
		pose.popMatrix();
	}

	/** Draws a full texture stretched over the rectangle, tinted by {@code color}. */
	public void texture(Identifier texture, float x, float y, float width, float height, int color) {
		Matrix3x2fStack pose = graphics.pose();
		pose.pushMatrix();
		pose.translate(x, y);
		pose.scale(width / 64f, height / 64f);
		graphics.blit(RenderPipelines.GUI_TEXTURED, texture, 0, 0, 0f, 0f, 64, 64, 64, 64, applyAlpha(color));
		pose.popMatrix();
	}

	/** Draws a sub-region {@code (u, v, regionWidth, regionHeight)} of a texture of size {@code textureWidth x textureHeight}. */
	public void textureRegion(Identifier texture, float x, float y, float width, float height,
		float u, float v, int regionWidth, int regionHeight, int textureWidth, int textureHeight, int color) {
		Matrix3x2fStack pose = graphics.pose();
		pose.pushMatrix();
		pose.translate(x, y);
		pose.scale(width / regionWidth, height / regionHeight);
		graphics.blit(RenderPipelines.GUI_TEXTURED, texture, 0, 0, u, v, regionWidth, regionHeight, textureWidth, textureHeight, applyAlpha(color));
		pose.popMatrix();
	}
}
