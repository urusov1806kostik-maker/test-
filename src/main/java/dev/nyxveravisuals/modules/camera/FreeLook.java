package dev.nyxveravisuals.modules.camera;

import org.lwjgl.glfw.GLFW;

import net.minecraft.client.CameraType;
import net.minecraft.client.Minecraft;
import net.minecraft.util.Mth;

import dev.nyxveravisuals.event.events.WorldLeaveEvent;
import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.setting.BooleanSetting;
import dev.nyxveravisuals.setting.Keybind;

/**
 * Look around without turning the player. While active, mouse movement rotates only the camera; the
 * player's real rotation (and what the server sees) does not change. The previous perspective is restored
 * on disable.
 */
public final class FreeLook extends Module {
	private final BooleanSetting thirdPerson = settings().add(new BooleanSetting("third_person", true));
	private final BooleanSetting invertPitch = settings().add(new BooleanSetting("invert_pitch", false));
	private float yaw;
	private float pitch;
	private CameraType previous;

	public FreeLook() {
		super("freelook", Category.CAMERA);
		bind().set(Keybind.key(GLFW.GLFW_KEY_LEFT_ALT));
		bindMode().set(BindMode.HOLD);
		on(WorldLeaveEvent.class, event -> setEnabled(false));
	}

	@Override
	protected void onEnable() {
		Minecraft minecraft = Minecraft.getInstance();
		if (minecraft.player == null) {
			previous = null;
			return;
		}
		yaw = minecraft.player.getYRot();
		pitch = minecraft.player.getXRot();
		previous = minecraft.options.getCameraType();
		if (thirdPerson.get() && previous.isFirstPerson()) {
			minecraft.options.setCameraType(CameraType.THIRD_PERSON_BACK);
		}
	}

	@Override
	protected void onDisable() {
		Minecraft minecraft = Minecraft.getInstance();
		if (previous != null && minecraft.options != null) {
			minecraft.options.setCameraType(previous);
		}
		previous = null;
	}

	/** Receives the mouse delta that would have turned the player. */
	public void turn(double deltaYaw, double deltaPitch) {
		yaw += (float) deltaYaw * 0.15f;
		pitch = Mth.clamp(pitch + (float) deltaPitch * 0.15f * (invertPitch.get() ? -1 : 1), -90f, 90f);
	}

	public float yaw() {
		return yaw;
	}

	public float pitch() {
		return pitch;
	}
}
