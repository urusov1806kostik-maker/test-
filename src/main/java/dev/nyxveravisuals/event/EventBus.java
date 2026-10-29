package dev.nyxveravisuals.event;

import java.util.Arrays;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Consumer;

import dev.nyxveravisuals.core.Log;

/**
 * Typed, allocation-free (on dispatch) event bus. Dispatch is by exact event class, listeners are kept in
 * copy-on-write arrays sorted by priority, and a failing listener never breaks the others: the failure is
 * routed to the {@link ErrorHandler}, which lets the owner (usually a module) be disabled in isolation.
 */
public final class EventBus {
	@FunctionalInterface
	public interface ErrorHandler {
		void onListenerError(Object owner, Object event, Throwable error);
	}

	private final Map<Class<?>, ListenerList> lists = new ConcurrentHashMap<>();
	private volatile ErrorHandler errorHandler = (owner, event, error) ->
		Log.error("Listener {} failed while handling {}", owner, event.getClass().getSimpleName(), error);

	public void setErrorHandler(ErrorHandler handler) {
		this.errorHandler = Objects.requireNonNull(handler);
	}

	public <E> Subscription subscribe(Class<E> type, Object owner, Consumer<? super E> handler) {
		return subscribe(type, owner, Priority.NORMAL, handler);
	}

	public <E> Subscription subscribe(Class<E> type, Object owner, Priority priority, Consumer<? super E> handler) {
		Objects.requireNonNull(type, "type");
		Objects.requireNonNull(owner, "owner");
		Objects.requireNonNull(handler, "handler");
		Listener listener = new Listener(owner, priority, handler);
		ListenerList list = lists.computeIfAbsent(type, ignored -> new ListenerList());
		list.add(listener);
		return new Subscription(this, type, listener);
	}

	void unsubscribe(Class<?> type, Listener listener) {
		ListenerList list = lists.get(type);
		if (list != null) {
			list.remove(listener);
		}
	}

	public boolean hasListeners(Class<?> type) {
		ListenerList list = lists.get(type);
		return list != null && list.listeners.length > 0;
	}

	/** Posts {@code event} to all listeners of its exact class and returns it (for cancellation checks). */
	public <E> E post(E event) {
		ListenerList list = lists.get(event.getClass());
		if (list == null) {
			return event;
		}
		Listener[] snapshot = list.listeners;
		for (Listener listener : snapshot) {
			if (!listener.active) {
				continue;
			}
			try {
				listener.invoke(event);
			} catch (Exception | LinkageError error) {
				errorHandler.onListenerError(listener.owner, event, error);
			}
			if (event instanceof Cancellable cancellable && cancellable.isCancelled() && !listener.priority.receivesCancelled()) {
				break;
			}
		}
		return event;
	}

	static final class Listener {
		final Object owner;
		final Priority priority;
		private final Consumer<Object> handler;
		volatile boolean active = true;

		@SuppressWarnings("unchecked")
		Listener(Object owner, Priority priority, Consumer<?> handler) {
			this.owner = owner;
			this.priority = priority;
			this.handler = (Consumer<Object>) handler;
		}

		void invoke(Object event) {
			handler.accept(event);
		}
	}

	private static final class ListenerList {
		private static final Listener[] EMPTY = new Listener[0];
		volatile Listener[] listeners = EMPTY;

		synchronized void add(Listener listener) {
			Listener[] current = listeners;
			Listener[] next = Arrays.copyOf(current, current.length + 1);
			int index = next.length - 1;
			while (index > 0 && next[index - 1].priority.ordinal() > listener.priority.ordinal()) {
				next[index] = next[index - 1];
				index--;
			}
			next[index] = listener;
			listeners = next;
		}

		synchronized void remove(Listener listener) {
			Listener[] current = listeners;
			for (int i = 0; i < current.length; i++) {
				if (current[i] == listener) {
					Listener[] next = new Listener[current.length - 1];
					System.arraycopy(current, 0, next, 0, i);
					System.arraycopy(current, i + 1, next, i, current.length - i - 1);
					listeners = next;
					return;
				}
			}
		}
	}
}
