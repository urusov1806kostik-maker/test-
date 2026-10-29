package dev.nyxveravisuals.event.events;

import dev.nyxveravisuals.render.WorldRenderer3D;

/** 3D render pass after the main world geometry; coordinates are camera-relative via the frame. */
public record WorldRenderEvent(WorldRenderer3D.Frame frame) {
}
