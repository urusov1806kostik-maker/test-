package dev.nyxveravisuals.event.events;

/** Raw mouse button input (GLFW button, action 0=release 1=press, modifier bits). */
public record MouseButtonInputEvent(int button, int action, int modifiers) {
	public boolean isPress() {
		return action == 1;
	}
}
