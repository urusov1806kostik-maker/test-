package dev.shadowvisuals.event.events;

import net.minecraft.client.DeltaTracker;

import dev.shadowvisuals.render.Renderer2D;

/** 2D render pass over the in-game HUD. The renderer is already bound to the frame's graphics. */
public record HudRenderEvent(Renderer2D renderer, DeltaTracker deltaTracker, float partialTick, float width, float height) {
}
