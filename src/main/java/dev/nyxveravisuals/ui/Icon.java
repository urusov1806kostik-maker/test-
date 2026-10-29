package dev.nyxveravisuals.ui;

import dev.nyxveravisuals.render.Renderer2D;

/**
 * Line icons drawn procedurally on a 24-unit grid with the anti-aliased shape renderer. One stroke style for
 * the whole client, crisp at every GUI scale, no texture atlas and no font glyph dependency.
 */
public enum Icon {
	EYE, EYE_OFF, LAYOUT, GLOBE, USER, CAMERA, WINDOW, TOOL, BOLT, STAR, STAR_FILLED, FOLDER, SLIDERS,
	SEARCH, CLOSE, CHECK, CHEVRON_DOWN, CHEVRON_RIGHT, CHEVRON_LEFT, RESET, PLUS, MINUS, TRASH, COPY, EDIT,
	KEYBOARD, PALETTE, INFO, WARNING, ERROR, SUCCESS, MOVE, GEAR, SAVE, USERS, PIN;

	private static final float STROKE = 2.0f;

	/** Draws the icon in a {@code size x size} box with its top-left at {@code (x, y)}. */
	public void draw(Renderer2D renderer, float x, float y, float size, int color) {
		Pen pen = new Pen(renderer, x, y, size / 24f, color);
		switch (this) {
			case EYE -> eye(pen);
			case EYE_OFF -> {
				eye(pen);
				pen.line(4, 4, 20, 20);
			}
			case LAYOUT -> {
				pen.box(3, 3, 21, 21, 3);
				pen.line(9.5f, 3.5f, 9.5f, 20.5f);
				pen.line(9.5f, 9.5f, 20.5f, 9.5f);
			}
			case GLOBE -> {
				pen.ring(12, 12, 9);
				pen.arc(12, 12, 4.2f, 9, -90, 270, 24);
				pen.line(3.5f, 12, 20.5f, 12);
			}
			case USER -> {
				pen.ring(12, 8, 4);
				pen.arc(12, 21, 8, 7, 180, 360, 18);
			}
			case USERS -> {
				pen.ring(9, 8, 3.5f);
				pen.arc(9, 20.5f, 6.5f, 6, 180, 360, 16);
				pen.arc(16.5f, 8, 3, 3.5f, -80, 80, 8);
				pen.arc(17.5f, 20.5f, 4.5f, 6, 270, 360, 8);
			}
			case CAMERA -> {
				pen.box(2.5f, 7, 21.5f, 20, 3);
				pen.ring(12, 13.5f, 3.6f);
				pen.polyline(false, 8, 7, 9.5f, 4, 14.5f, 4, 16, 7);
			}
			case WINDOW -> {
				pen.box(3, 4, 21, 20, 3);
				pen.line(3.5f, 9, 20.5f, 9);
				pen.dot(6.5f, 6.5f, 1.1f);
				pen.dot(9.5f, 6.5f, 1.1f);
			}
			case TOOL -> {
				pen.line(5, 19, 13.5f, 10.5f);
				pen.ring(16.5f, 7.5f, 4);
			}
			case BOLT -> pen.polyline(true, 13, 2.5f, 4.5f, 13.5f, 11, 13.5f, 10, 21.5f, 19.5f, 9.5f, 13, 9.5f);
			case STAR -> pen.polyline(true, star(pen));
			case STAR_FILLED -> {
				float[] points = star(pen);
				pen.fill(12, 12.6f, points);
				pen.polyline(true, points);
			}
			case FOLDER -> pen.polyline(true, 3, 6, 9.5f, 6, 11.5f, 8.5f, 21, 8.5f, 21, 19, 3, 19);
			case SLIDERS -> {
				pen.line(4, 7, 20, 7);
				pen.line(4, 12, 20, 12);
				pen.line(4, 17, 20, 17);
				pen.dot(9, 7, 2.4f);
				pen.dot(15, 12, 2.4f);
				pen.dot(7, 17, 2.4f);
			}
			case SEARCH -> {
				pen.ring(10.5f, 10.5f, 6);
				pen.line(15, 15, 20, 20);
			}
			case CLOSE -> {
				pen.line(6, 6, 18, 18);
				pen.line(18, 6, 6, 18);
			}
			case CHECK -> pen.polyline(false, 5, 12.5f, 10, 17, 19, 7);
			case CHEVRON_DOWN -> pen.polyline(false, 6, 9.5f, 12, 15.5f, 18, 9.5f);
			case CHEVRON_RIGHT -> pen.polyline(false, 9.5f, 6, 15.5f, 12, 9.5f, 18);
			case CHEVRON_LEFT -> pen.polyline(false, 14.5f, 6, 8.5f, 12, 14.5f, 18);
			case RESET -> {
				pen.arc(12, 12, 7.5f, 7.5f, -60, 225, 22);
				pen.polyline(false, 18.5f, 3.5f, 16, 8, 11.5f, 6);
			}
			case PLUS -> {
				pen.line(12, 5, 12, 19);
				pen.line(5, 12, 19, 12);
			}
			case MINUS -> pen.line(5, 12, 19, 12);
			case TRASH -> {
				pen.line(4, 7, 20, 7);
				pen.polyline(false, 9, 7, 9, 4, 15, 4, 15, 7);
				pen.polyline(false, 6.5f, 7, 7.5f, 20, 16.5f, 20, 17.5f, 7);
			}
			case COPY -> {
				pen.box(8, 8, 20, 20, 2.5f);
				pen.polyline(false, 16, 8, 16, 4, 4, 4, 4, 16, 8, 16);
			}
			case EDIT -> {
				pen.line(5, 19, 16, 8);
				pen.line(14, 6, 18, 10);
				pen.line(4.5f, 19.5f, 8, 19.5f);
			}
			case KEYBOARD -> {
				pen.box(2.5f, 6, 21.5f, 18, 3);
				pen.dot(7, 10, 1.1f);
				pen.dot(10.5f, 10, 1.1f);
				pen.dot(14, 10, 1.1f);
				pen.dot(17.5f, 10, 1.1f);
				pen.line(8, 14.5f, 16, 14.5f);
			}
			case PALETTE -> {
				pen.ring(12, 12, 9);
				pen.dot(8, 9.5f, 1.5f);
				pen.dot(12, 7.5f, 1.5f);
				pen.dot(16, 9.5f, 1.5f);
				pen.dot(15, 15, 1.8f);
			}
			case INFO -> {
				pen.ring(12, 12, 9);
				pen.line(12, 11, 12, 16.5f);
				pen.dot(12, 7.8f, 1.2f);
			}
			case WARNING -> {
				pen.polyline(true, 12, 3.5f, 21.5f, 20, 2.5f, 20);
				pen.line(12, 9.5f, 12, 14);
				pen.dot(12, 17, 1.2f);
			}
			case ERROR -> {
				pen.ring(12, 12, 9);
				pen.line(9, 9, 15, 15);
				pen.line(15, 9, 9, 15);
			}
			case SUCCESS -> {
				pen.ring(12, 12, 9);
				pen.polyline(false, 8, 12.5f, 11, 15.5f, 16.5f, 9);
			}
			case MOVE -> {
				pen.line(12, 3, 12, 21);
				pen.line(3, 12, 21, 12);
				pen.polyline(false, 9, 6, 12, 3, 15, 6);
				pen.polyline(false, 9, 18, 12, 21, 15, 18);
				pen.polyline(false, 6, 9, 3, 12, 6, 15);
				pen.polyline(false, 18, 9, 21, 12, 18, 15);
			}
			case GEAR -> {
				pen.ring(12, 12, 3);
				pen.ring(12, 12, 7);
				for (int i = 0; i < 8; i++) {
					double angle = Math.PI / 4 * i;
					float cos = (float) Math.cos(angle);
					float sin = (float) Math.sin(angle);
					pen.line(12 + cos * 7.5f, 12 + sin * 7.5f, 12 + cos * 9.8f, 12 + sin * 9.8f);
				}
			}
			case SAVE -> {
				pen.line(12, 4, 12, 15);
				pen.polyline(false, 7.5f, 10.5f, 12, 15, 16.5f, 10.5f);
				pen.polyline(false, 4, 15.5f, 4, 20, 20, 20, 20, 15.5f);
			}
			case PIN -> {
				pen.ring(12, 9, 5);
				pen.line(12, 14, 12, 21);
			}
		}
	}

	private static void eye(Pen pen) {
		pen.arc(12, 12, 10, 6.5f, 180, 360, 20);
		pen.arc(12, 12, 10, 6.5f, 0, 180, 20);
		pen.ring(12, 12, 3);
	}

	private static float[] star(Pen pen) {
		float[] points = new float[20];
		for (int i = 0; i < 10; i++) {
			double angle = -Math.PI / 2 + Math.PI / 5 * i;
			float radius = i % 2 == 0 ? 9.5f : 4.1f;
			points[i * 2] = 12 + (float) Math.cos(angle) * radius;
			points[i * 2 + 1] = 12.6f + (float) Math.sin(angle) * radius;
		}
		return points;
	}

	/** Maps the 24-unit icon grid onto the target box. */
	private static final class Pen {
		private final Renderer2D renderer;
		private final float x;
		private final float y;
		private final float scale;
		private final int color;
		private final float stroke;

		Pen(Renderer2D renderer, float x, float y, float scale, int color) {
			this.renderer = renderer;
			this.x = x;
			this.y = y;
			this.scale = scale;
			this.color = color;
			this.stroke = Math.max(0.75f, STROKE * scale);
		}

		float px(float value) {
			return x + value * scale;
		}

		float py(float value) {
			return y + value * scale;
		}

		void line(float x0, float y0, float x1, float y1) {
			renderer.line(px(x0), py(y0), px(x1), py(y1), stroke, color);
		}

		void polyline(boolean closed, float... points) {
			float[] mapped = new float[points.length];
			for (int i = 0; i < points.length; i += 2) {
				mapped[i] = px(points[i]);
				mapped[i + 1] = py(points[i + 1]);
			}
			renderer.polyline(mapped, stroke, color, closed);
		}

		void ring(float cx, float cy, float radius) {
			renderer.ring(px(cx), py(cy), radius * scale + stroke / 2, stroke, color);
		}

		void dot(float cx, float cy, float radius) {
			renderer.circle(px(cx), py(cy), radius * scale, color);
		}

		void box(float x0, float y0, float x1, float y1, float radius) {
			float half = stroke / 2;
			renderer.outline(px(x0) - half, py(y0) - half, (x1 - x0) * scale + stroke, (y1 - y0) * scale + stroke,
				radius * scale + half, stroke, color);
		}

		void fill(float cx, float cy, float[] points) {
			float[] mapped = new float[points.length];
			for (int i = 0; i < points.length; i += 2) {
				mapped[i] = px(points[i]);
				mapped[i + 1] = py(points[i + 1]);
			}
			renderer.fan(px(cx), py(cy), mapped, color);
		}

		/** Elliptic arc from {@code startDeg} to {@code endDeg} (0 = +x, 90 = +y). */
		void arc(float cx, float cy, float radiusX, float radiusY, float startDeg, float endDeg, int segments) {
			float[] points = new float[(segments + 1) * 2];
			for (int i = 0; i <= segments; i++) {
				double angle = Math.toRadians(startDeg + (endDeg - startDeg) * i / segments);
				points[i * 2] = px(cx + (float) Math.cos(angle) * radiusX);
				points[i * 2 + 1] = py(cy + (float) Math.sin(angle) * radiusY);
			}
			renderer.polyline(points, stroke, color, false);
		}
	}
}
