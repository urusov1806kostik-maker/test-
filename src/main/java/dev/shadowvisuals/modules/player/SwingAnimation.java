package dev.shadowvisuals.modules.player;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;

import net.minecraft.util.Mth;
import net.minecraft.world.entity.HumanoidArm;

import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.setting.ModeSetting;
import dev.shadowvisuals.setting.NumberSetting;

/**
 * First-person swing presets. Purely visual: it only changes how the arm moves for the existing swing
 * progress, never the swing duration or attack timing.
 */
public final class SwingAnimation extends Module {
	public enum Style {
		SMOOTH,
		SLIDE,
		STAB,
		WAVE,
		MINIMAL
	}

	private final ModeSetting<Style> style = settings().add(new ModeSetting<>("style", Style.SMOOTH));
	private final NumberSetting intensity = settings().add(new NumberSetting("intensity", 1.0, 0.2, 2.0, 0.05).suffix("x"));

	public SwingAnimation() {
		super("swing_animation", Category.PLAYER);
	}

	@Override
	public String listSuffix() {
		return style.get().name().charAt(0) + style.get().name().substring(1).toLowerCase(java.util.Locale.ROOT);
	}

	/** Replaces the vanilla attack transform for {@code progress} in {@code 0..1}. */
	public void apply(PoseStack poses, HumanoidArm arm, float progress) {
		int side = arm == HumanoidArm.RIGHT ? 1 : -1;
		float k = intensity.getFloat();
		float wave = Mth.sin(progress * (float) Math.PI);
		float eased = Mth.sin(Mth.sqrt(progress) * (float) Math.PI);
		switch (style.get()) {
			case SMOOTH -> {
				poses.mulPose(Axis.YP.rotationDegrees(side * (45f - 14f * wave * k)));
				poses.mulPose(Axis.ZP.rotationDegrees(side * eased * -12f * k));
				poses.mulPose(Axis.XP.rotationDegrees(eased * -55f * k));
				poses.mulPose(Axis.YP.rotationDegrees(side * -45f));
			}
			case SLIDE -> {
				poses.translate(0, -0.12f * wave * k, -0.05f * wave * k);
				poses.mulPose(Axis.XP.rotationDegrees(eased * -25f * k));
			}
			case STAB -> poses.translate(0, 0.02f * wave * k, -0.35f * eased * k);
			case WAVE -> {
				poses.mulPose(Axis.ZP.rotationDegrees(side * eased * 35f * k));
				poses.mulPose(Axis.XP.rotationDegrees(eased * -20f * k));
			}
			case MINIMAL -> poses.translate(0, -0.05f * wave * k, -0.08f * wave * k);
		}
	}
}
