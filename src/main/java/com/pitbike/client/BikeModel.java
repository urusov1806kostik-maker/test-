package com.pitbike.client;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.mojang.math.Axis;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.packs.resources.ResourceManager;
import org.jetbrains.annotations.Nullable;
import org.joml.Matrix3f;
import org.joml.Matrix4f;

import java.io.IOException;
import java.io.Reader;
import java.util.ArrayList;
import java.util.List;

/**
 * Mesh model exported from Blockbench by tools/convert_bbmodel.py.
 * Coordinates are model pixels, Y up, bike facing +Z.
 */
public final class BikeModel {
    /** Floats per quad: 4 vertices of (x, y, z, u, v) followed by the normal. */
    private static final int QUAD_STRIDE = 23;

    private final List<Bone> roots;
    private final float[] sample = new float[3];

    private BikeModel(List<Bone> roots) {
        this.roots = roots;
    }

    public static BikeModel load(ResourceManager resources, ResourceLocation location) {
        try (Reader reader = resources.openAsReader(location)) {
            JsonObject root = JsonParser.parseReader(reader).getAsJsonObject();
            List<Bone> bones = new ArrayList<>();
            for (JsonElement bone : root.getAsJsonArray("bones")) {
                bones.add(readBone(bone.getAsJsonObject()));
            }
            return new BikeModel(bones);
        } catch (IOException | RuntimeException e) {
            throw new IllegalStateException("Failed to load model " + location, e);
        }
    }

    private static Bone readBone(JsonObject json) {
        JsonArray quadsJson = json.getAsJsonArray("quads");
        float[] quads = new float[quadsJson.size() * QUAD_STRIDE];
        for (int i = 0; i < quadsJson.size(); i++) {
            JsonArray quad = quadsJson.get(i).getAsJsonArray();
            for (int j = 0; j < QUAD_STRIDE; j++) {
                quads[i * QUAD_STRIDE + j] = quad.get(j).getAsFloat();
            }
        }
        List<Bone> children = new ArrayList<>();
        for (JsonElement child : json.getAsJsonArray("children")) {
            children.add(readBone(child.getAsJsonObject()));
        }
        return new Bone(json.get("name").getAsString(), readVec(json.getAsJsonArray("pivot")),
                readVec(json.getAsJsonArray("rotation")), quads, children);
    }

    private static float[] readVec(JsonArray array) {
        return new float[]{array.get(0).getAsFloat(), array.get(1).getAsFloat(), array.get(2).getAsFloat()};
    }

    public void render(PoseStack pose, VertexConsumer consumer, int light, int overlay,
                       @Nullable BikeAnimation animation, float animTime) {
        for (Bone bone : this.roots) {
            this.renderBone(bone, pose, consumer, light, overlay, animation, animTime);
        }
    }

    private void renderBone(Bone bone, PoseStack pose, VertexConsumer consumer, int light, int overlay,
                            @Nullable BikeAnimation animation, float animTime) {
        pose.pushPose();
        float[] s = this.sample;
        pose.translate(bone.pivot[0], bone.pivot[1], bone.pivot[2]);
        if (animation != null && animation.sample(bone.name, BikeAnimation.POSITION, animTime, s)) {
            pose.translate(s[0], s[1], s[2]);
        }
        float rx = bone.rotation[0] * ((float) Math.PI / 180F);
        float ry = bone.rotation[1] * ((float) Math.PI / 180F);
        float rz = bone.rotation[2] * ((float) Math.PI / 180F);
        if (animation != null && animation.sample(bone.name, BikeAnimation.ROTATION, animTime, s)) {
            rx += s[0];
            ry += s[1];
            rz += s[2];
        }
        // Blockbench uses ZYX euler order.
        if (rz != 0) pose.mulPose(Axis.ZP.rotation(rz));
        if (ry != 0) pose.mulPose(Axis.YP.rotation(ry));
        if (rx != 0) pose.mulPose(Axis.XP.rotation(rx));
        if (animation != null && animation.sample(bone.name, BikeAnimation.SCALE, animTime, s)) {
            pose.scale(s[0], s[1], s[2]);
        }
        pose.translate(-bone.pivot[0], -bone.pivot[1], -bone.pivot[2]);

        Matrix4f matrix = pose.last().pose();
        Matrix3f normal = pose.last().normal();
        float[] q = bone.quads;
        for (int i = 0; i < q.length; i += QUAD_STRIDE) {
            for (int v = 0; v < 4; v++) {
                int o = i + v * 5;
                consumer.vertex(matrix, q[o], q[o + 1], q[o + 2])
                        .color(255, 255, 255, 255)
                        .uv(q[o + 3], q[o + 4])
                        .overlayCoords(overlay)
                        .uv2(light)
                        .normal(normal, q[i + 20], q[i + 21], q[i + 22])
                        .endVertex();
            }
        }

        for (Bone child : bone.children) {
            this.renderBone(child, pose, consumer, light, overlay, animation, animTime);
        }
        pose.popPose();
    }

    private record Bone(String name, float[] pivot, float[] rotation, float[] quads, List<Bone> children) {
    }
}
