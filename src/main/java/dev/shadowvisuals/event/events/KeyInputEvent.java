package dev.shadowvisuals.event.events;

/** Raw keyboard input (GLFW key, scancode, action 0=release 1=press 2=repeat, modifier bits). */
public record KeyInputEvent(int key, int scancode, int action, int modifiers) {
	public boolean isPress() {
		return action == 1;
	}

	public boolean isRelease() {
		return action == 0;
	}
}
