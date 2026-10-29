package dev.nyxveravisuals.ui.settings;

import java.util.function.BooleanSupplier;

import dev.nyxveravisuals.core.UiSounds;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.render.font.FontManager;
import dev.nyxveravisuals.setting.ActionSetting;
import dev.nyxveravisuals.setting.BooleanSetting;
import dev.nyxveravisuals.setting.ColorSetting;
import dev.nyxveravisuals.setting.IntSetting;
import dev.nyxveravisuals.setting.KeybindSetting;
import dev.nyxveravisuals.setting.ModeSetting;
import dev.nyxveravisuals.setting.MultiSelectSetting;
import dev.nyxveravisuals.setting.NumberSetting;
import dev.nyxveravisuals.setting.RangeSetting;
import dev.nyxveravisuals.setting.Setting;
import dev.nyxveravisuals.setting.SettingNode;
import dev.nyxveravisuals.setting.StringSetting;
import dev.nyxveravisuals.theme.DesignTokens;
import dev.nyxveravisuals.theme.ThemeManager;
import dev.nyxveravisuals.ui.Icon;
import dev.nyxveravisuals.ui.UiContext;
import dev.nyxveravisuals.ui.component.Button;
import dev.nyxveravisuals.ui.component.ColorSwatch;
import dev.nyxveravisuals.ui.component.Component;
import dev.nyxveravisuals.ui.component.Dropdown;
import dev.nyxveravisuals.ui.component.KeybindSelector;
import dev.nyxveravisuals.ui.component.RangeSlider;
import dev.nyxveravisuals.ui.component.Slider;
import dev.nyxveravisuals.ui.component.TextField;
import dev.nyxveravisuals.ui.component.Toggle;
import dev.nyxveravisuals.ui.overlay.ContextMenu;
import dev.nyxveravisuals.ui.overlay.Dialog;
import dev.nyxveravisuals.util.ColorUtil;

/**
 * One row of the settings list: localized label, the control matching the setting type, a reset button
 * when the value differs from the default, and the description as a tooltip. The row only displays and
 * edits the setting; the value always lives in the {@link Setting}.
 */
public final class SettingRow extends Component {
	private enum Kind {
		INLINE,
		SLIDER,
		TEXT,
		ACTION
	}

	private final SettingNode node;
	private final BooleanSupplier groupExpanded;
	private final float indent;
	private final Component control;
	private final Kind kind;
	private final Button resetButton;

	public SettingRow(UiContext context, SettingNode node, BooleanSupplier groupExpanded, float indent) {
		this.node = node;
		this.groupExpanded = groupExpanded;
		this.indent = indent;
		this.resetButton = Button.icon(Icon.RESET, "ui.reset_setting", node::reset);
		if (node instanceof BooleanSetting setting) {
			control = new Toggle(setting::get, setting::set);
			kind = Kind.INLINE;
		} else if (node instanceof NumberSetting setting) {
			control = new Slider(new Slider.Model() {
				@Override
				public double progress() {
					return setting.progress();
				}

				@Override
				public void setProgress(double progress) {
					setting.setProgress(progress);
				}

				@Override
				public void step(int steps) {
					setting.set(setting.get() + steps * setting.step());
				}
			});
			kind = Kind.SLIDER;
		} else if (node instanceof IntSetting setting) {
			control = new Slider(new Slider.Model() {
				@Override
				public double progress() {
					return setting.progress();
				}

				@Override
				public void setProgress(double progress) {
					setting.setProgress(progress);
				}

				@Override
				public void step(int steps) {
					setting.set(setting.get() + steps * setting.step());
				}
			});
			kind = Kind.SLIDER;
		} else if (node instanceof RangeSetting setting) {
			control = new RangeSlider(setting);
			kind = Kind.SLIDER;
		} else if (node instanceof ModeSetting<?> setting) {
			control = modeDropdown(context, setting);
			kind = Kind.INLINE;
		} else if (node instanceof MultiSelectSetting<?> setting) {
			control = multiDropdown(context, setting);
			kind = Kind.INLINE;
		} else if (node instanceof ColorSetting setting) {
			control = new ColorSwatch(setting);
			kind = Kind.INLINE;
		} else if (node instanceof KeybindSetting setting) {
			control = new KeybindSelector(setting);
			kind = Kind.INLINE;
		} else if (node instanceof StringSetting setting) {
			TextField field = new TextField(setting.maxLength());
			field.setText(setting.get());
			field.onChange(value -> {
				if (setting.accepts(value)) {
					setting.set(value);
				}
			});
			control = field;
			kind = Kind.TEXT;
		} else if (node instanceof ActionSetting setting) {
			control = new Button(setting.translationKey(), null, setting.requiresConfirmation() ? Button.Style.DANGER : Button.Style.SECONDARY,
				() -> {
					if (setting.requiresConfirmation()) {
						Dialog.confirm(context, setting.translationKey(), context.tr("ui.confirm_action"), "ui.confirm", true, setting::run);
					} else {
						setting.run();
					}
				});
			kind = Kind.ACTION;
		} else {
			throw new IllegalArgumentException("No row for setting type " + node.getClass().getName());
		}
	}

	private static <E extends Enum<E>> Component modeDropdown(UiContext context, ModeSetting<E> setting) {
		return Dropdown.single(setting::modes, mode -> context.i18n().enumName(mode), setting::get, setting::set);
	}

	private static <E extends Enum<E>> Component multiDropdown(UiContext context, MultiSelectSetting<E> setting) {
		return Dropdown.multi(setting::options, option -> context.i18n().enumName(option), setting::contains, setting::toggle, () -> {
			int count = setting.get().size();
			if (count == 0) {
				return context.tr("ui.multi.none");
			}
			if (count == 1) {
				return context.i18n().enumName(setting.get().iterator().next());
			}
			return context.tr("ui.multi.count", count);
		});
	}

	public SettingNode node() {
		return node;
	}

	@Override
	public boolean isVisible() {
		return node.isVisible() && groupExpanded.getAsBoolean();
	}

	@Override
	public float preferredHeight(UiContext context, float availableWidth) {
		return switch (kind) {
			case SLIDER -> 27;
			case TEXT -> 34;
			case ACTION -> 20;
			default -> DesignTokens.ROW_HEIGHT + 2;
		};
	}

	private boolean modified() {
		return node instanceof Setting<?> setting && !setting.isDefault();
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		float left = x + indent;
		float rowWidth = width - indent;
		if (hover() > 0.01f && kind != Kind.ACTION) {
			renderer.rounded(left - 4, y, rowWidth + 4, height, DesignTokens.RADIUS_S, ColorUtil.withAlpha(theme.textPrimary(), Math.round(hover() * 9)));
		}
		float size = context.text(DesignTokens.FONT_SMALL);
		String label = context.i18n().settingName(node);
		float resetSize = 11;
		boolean showReset = modified() && (isHovered() || resetButton.isHovered());

		switch (kind) {
			case ACTION -> {
				control.setBounds(left, y + 1, rowWidth, height - 2);
				control.render(context, mouseX, mouseY);
				return;
			}
			case SLIDER -> {
				String value = valueText();
				float valueWidth = renderer.textWidth(value, size);
				float labelMax = rowWidth - valueWidth - (showReset ? resetSize + 4 : 0) - 8;
				renderer.textMiddle(renderer.ellipsize(label, size, FontManager.Weight.MEDIUM, labelMax), left, y + 8, size, theme.textPrimary());
				renderer.text(value, x + width, y + 8 - context.renderer().fonts().visualCenter(size), size, theme.textSecondary(), Renderer2D.Align.RIGHT);
				if (showReset) {
					resetButton.setBounds(x + width - valueWidth - resetSize - 4, y + 2.5f, resetSize, resetSize);
				}
				control.setBounds(left, y + 15, rowWidth, 10);
			}
			case TEXT -> {
				if (node instanceof StringSetting setting && control instanceof TextField field
					&& !context.isFocused(field) && !setting.get().equals(field.text())) {
					field.setText(setting.get());
				}
				renderer.textMiddle(renderer.ellipsize(label, size, FontManager.Weight.MEDIUM, rowWidth - resetSize - 6), left, y + 7, size, theme.textPrimary());
				if (showReset) {
					resetButton.setBounds(x + width - resetSize, y + 1.5f, resetSize, resetSize);
				}
				control.setBounds(left, y + 15, rowWidth, 17);
			}
			default -> {
				float controlWidth = controlWidth(context, rowWidth);
				float controlHeight = control.height();
				control.setBounds(x + width - controlWidth, y + (height - controlHeight) / 2f, controlWidth, controlHeight);
				float labelMax = rowWidth - controlWidth - (showReset ? resetSize + 4 : 0) - 8;
				renderer.textMiddle(renderer.ellipsize(label, size, FontManager.Weight.MEDIUM, labelMax), left, y + height / 2f, size, theme.textPrimary());
				if (showReset) {
					resetButton.setBounds(x + width - controlWidth - resetSize - 4, y + (height - resetSize) / 2f, resetSize, resetSize);
				}
			}
		}
		if (!showReset) {
			resetButton.setBounds(-1e6f, -1e6f, 0, 0);
		}
		control.render(context, mouseX, mouseY);
		resetButton.render(context, mouseX, mouseY);
	}

	private float controlWidth(UiContext context, float rowWidth) {
		if (control instanceof Dropdown<?> dropdown) {
			return Math.min(rowWidth * 0.5f, Math.max(56, dropdown.preferredWidth(context)));
		}
		if (control instanceof KeybindSelector selector) {
			return Math.min(rowWidth * 0.5f, selector.preferredWidth(context));
		}
		return control.width();
	}

	private String valueText() {
		if (node instanceof NumberSetting setting) {
			return setting.format();
		}
		if (node instanceof IntSetting setting) {
			return setting.format();
		}
		if (node instanceof RangeSetting setting) {
			return setting.format();
		}
		return "";
	}

	@Override
	protected String tooltip(UiContext context) {
		return context.i18n().settingDescription(node);
	}

	@Override
	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		if (resetButton.mouseClicked(context, mouseX, mouseY, button)) {
			return true;
		}
		if (control.mouseClicked(context, mouseX, mouseY, button)) {
			return true;
		}
		if (button == 1 && contains(mouseX, mouseY) && node instanceof Setting<?>) {
			ContextMenu.at(mouseX, mouseY)
				.item("ui.reset_setting", Icon.RESET, node::reset)
				.open(context);
			return true;
		}
		if (button == 0 && contains(mouseX, mouseY) && node instanceof BooleanSetting setting && kind == Kind.INLINE) {
			setting.toggle();
			context.sounds().play(setting.get() ? UiSounds.Kind.TOGGLE_ON : UiSounds.Kind.TOGGLE_OFF);
			return true;
		}
		return contains(mouseX, mouseY);
	}

	@Override
	public boolean mouseDragged(UiContext context, float mouseX, float mouseY, int button) {
		return control.mouseDragged(context, mouseX, mouseY, button);
	}

	@Override
	public boolean mouseReleased(UiContext context, float mouseX, float mouseY, int button) {
		return control.mouseReleased(context, mouseX, mouseY, button);
	}

	@Override
	public boolean keyPressed(UiContext context, int key, int scancode, int modifiers) {
		return control.keyPressed(context, key, scancode, modifiers);
	}

	@Override
	public boolean charTyped(UiContext context, int codePoint) {
		return control.charTyped(context, codePoint);
	}
}
