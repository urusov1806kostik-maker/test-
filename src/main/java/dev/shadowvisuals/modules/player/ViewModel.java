package dev.shadowvisuals.modules.player;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;

import net.minecraft.world.InteractionHand;

import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.setting.NumberSetting;
import dev.shadowvisuals.setting.SettingGroup;

/** Per-hand position, rotation and scale of first-person items. Every value has its own reset. */
public final class ViewModel extends Module {
	private final Hand main = new Hand("main_hand");
	private final Hand off = new Hand("off_hand");

	private final class Hand {
		final NumberSetting x;
		final NumberSetting y;
		final NumberSetting z;
		final NumberSetting rotationX;
		final NumberSetting rotationY;
		final NumberSetting rotationZ;
		final NumberSetting scale;

		Hand(String prefix) {
			SettingGroup group = settings().add(new SettingGroup(prefix));
			x = settings().add(group, new NumberSetting(prefix + "_x", 0, -1, 1, 0.01));
			y = settings().add(group, new NumberSetting(prefix + "_y", 0, -1, 1, 0.01));
			z = settings().add(group, new NumberSetting(prefix + "_z", 0, -1, 1, 0.01));
			rotationX = settings().add(group, new NumberSetting(prefix + "_rotation_x", 0, -180, 180, 1).suffix("°"));
			rotationY = settings().add(group, new NumberSetting(prefix + "_rotation_y", 0, -180, 180, 1).suffix("°"));
			rotationZ = settings().add(group, new NumberSetting(prefix + "_rotation_z", 0, -180, 180, 1).suffix("°"));
			scale = settings().add(group, new NumberSetting(prefix + "_scale", 1, 0.3, 2, 0.05).suffix("x"));
		}
	}

	public ViewModel() {
		super("view_model", Category.PLAYER);
	}

	public void apply(PoseStack poses, InteractionHand hand) {
		Hand values = hand == InteractionHand.MAIN_HAND ? main : off;
		poses.translate(values.x.getFloat(), values.y.getFloat(), values.z.getFloat());
		if (values.rotationX.getFloat() != 0) {
			poses.mulPose(Axis.XP.rotationDegrees(values.rotationX.getFloat()));
		}
		if (values.rotationY.getFloat() != 0) {
			poses.mulPose(Axis.YP.rotationDegrees(values.rotationY.getFloat()));
		}
		if (values.rotationZ.getFloat() != 0) {
			poses.mulPose(Axis.ZP.rotationDegrees(values.rotationZ.getFloat()));
		}
		float scale = values.scale.getFloat();
		if (scale != 1f) {
			poses.scale(scale, scale, scale);
		}
	}
}
