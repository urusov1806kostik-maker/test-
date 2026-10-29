package dev.nyxveravisuals.notification;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Objects;

import dev.nyxveravisuals.animation.Animation;
import dev.nyxveravisuals.animation.AnimationClock;
import dev.nyxveravisuals.animation.Easing;

/**
 * Bounded notification queue. At most {@link #MAX_ACTIVE} notifications exist; when full, the oldest one is
 * dismissed. Identical messages refresh the existing entry instead of stacking.
 */
public final class NotificationManager {
	public enum Type {
		INFO,
		SUCCESS,
		WARNING,
		ERROR
	}

	public static final int MAX_ACTIVE = 5;
	public static final float DEFAULT_DURATION = 3.5f;
	private static final float ANIMATION_SECONDS = 0.28f;

	public static final class Notification {
		private final Type type;
		private final String title;
		private final String message;
		private final float duration;
		private final Animation visibility;
		private final Animation slot;
		private double shownAt;
		private boolean dismissed;

		Notification(Type type, String title, String message, float duration, AnimationClock clock, float slotIndex) {
			this.type = type;
			this.title = title;
			this.message = message;
			this.duration = duration;
			this.visibility = new Animation(clock, 0f, ANIMATION_SECONDS, Easing.EASE_OUT_CUBIC);
			this.slot = new Animation(clock, slotIndex, ANIMATION_SECONDS, Easing.EASE_OUT_CUBIC);
			this.visibility.animateTo(1f);
			this.shownAt = clock.now();
		}

		public Type type() {
			return type;
		}

		public String title() {
			return title;
		}

		public String message() {
			return message;
		}

		/** Appearance progress {@code 0..1}. */
		public float visibility() {
			return visibility.value();
		}

		/** Smoothly animated stack position (0 = newest slot). */
		public float slot() {
			return slot.value();
		}

		/** Remaining lifetime as {@code 1..0}, for progress bars. */
		public float remaining(double now) {
			return dismissed ? 0f : (float) Math.max(0, 1 - (now - shownAt) / duration);
		}

		void dismiss() {
			if (!dismissed) {
				dismissed = true;
				visibility.animateTo(0f);
			}
		}

		boolean sameContent(Type otherType, String otherTitle, String otherMessage) {
			return type == otherType && title.equals(otherTitle) && message.equals(otherMessage);
		}
	}

	private final AnimationClock clock;
	private final List<Notification> active = new ArrayList<>(MAX_ACTIVE + 2);
	private final List<Notification> view = Collections.unmodifiableList(active);
	private boolean enabled = true;

	public NotificationManager() {
		this(AnimationClock.global());
	}

	public NotificationManager(AnimationClock clock) {
		this.clock = Objects.requireNonNull(clock);
	}

	public void setEnabled(boolean value) {
		this.enabled = value;
		if (!value) {
			active.clear();
		}
	}

	public void push(Type type, String title, String message) {
		push(type, title, message, DEFAULT_DURATION);
	}

	public void push(Type type, String title, String message, float durationSeconds) {
		if (!enabled) {
			return;
		}
		String safeTitle = title == null ? "" : title;
		String safeMessage = message == null ? "" : message;
		for (Notification existing : active) {
			if (!existing.dismissed && existing.sameContent(type, safeTitle, safeMessage)) {
				existing.shownAt = clock.now();
				return;
			}
		}
		int alive = 0;
		for (Notification notification : active) {
			if (!notification.dismissed) {
				alive++;
			}
		}
		if (alive >= MAX_ACTIVE) {
			for (Notification notification : active) {
				if (!notification.dismissed) {
					notification.dismiss();
					break;
				}
			}
		}
		active.add(new Notification(type, safeTitle, safeMessage, Math.max(0.5f, durationSeconds), clock, -1f));
		relayout();
	}

	/** Expires old notifications and removes fully hidden ones. Call once per frame before rendering. */
	public void update() {
		double now = clock.now();
		boolean changed = false;
		for (Notification notification : active) {
			if (!notification.dismissed && now - notification.shownAt >= notification.duration) {
				notification.dismiss();
				changed = true;
			}
		}
		if (active.removeIf(notification -> notification.dismissed && notification.visibility.isFinishedAtZero())) {
			changed = true;
		}
		if (changed) {
			relayout();
		}
	}

	private void relayout() {
		int slot = 0;
		for (int i = active.size() - 1; i >= 0; i--) {
			Notification notification = active.get(i);
			if (!notification.dismissed) {
				notification.slot.animateTo(slot++);
			}
		}
	}

	/** Oldest first; renderers iterate this read-only view. */
	public List<Notification> active() {
		return view;
	}

	public void clear() {
		active.clear();
	}
}
