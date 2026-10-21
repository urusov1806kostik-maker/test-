package com.pitbike.client;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.packs.resources.ResourceManager;
import net.minecraft.util.Mth;

import java.io.IOException;
import java.io.Reader;
import java.util.HashMap;
import java.util.Map;

/**
 * Keyframe animation exported from Blockbench by tools/convert_bbmodel.py.
 * Values are already in "apply" form: position in pixels, rotation in radians, scale as factors.
 */
public final class BikeAnimation {
    public static final int POSITION = 0;
    public static final int ROTATION = 1;
    public static final int SCALE = 2;
    private static final String[] CHANNELS = {"position", "rotation", "scale"};

    private final float length;
    private final boolean loop;
    /** bone name -> channel -> keyframes of {time, x, y, z, step}. */
    private final Map<String, float[][][]> bones;

    private BikeAnimation(float length, boolean loop, Map<String, float[][][]> bones) {
        this.length = length;
        this.loop = loop;
        this.bones = bones;
    }

    public static Map<String, BikeAnimation> load(ResourceManager resources, ResourceLocation location) {
        Map<String, BikeAnimation> result = new HashMap<>();
        try (Reader reader = resources.openAsReader(location)) {
            JsonObject root = JsonParser.parseReader(reader).getAsJsonObject();
            for (Map.Entry<String, JsonElement> anim : root.entrySet()) {
                JsonObject json = anim.getValue().getAsJsonObject();
                Map<String, float[][][]> bones = new HashMap<>();
                for (Map.Entry<String, JsonElement> bone : json.getAsJsonObject("bones").entrySet()) {
                    JsonObject channels = bone.getValue().getAsJsonObject();
                    float[][][] frames = new float[CHANNELS.length][][];
                    for (int c = 0; c < CHANNELS.length; c++) {
                        if (channels.has(CHANNELS[c])) {
                            frames[c] = readFrames(channels.getAsJsonArray(CHANNELS[c]));
                        }
                    }
                    bones.put(bone.getKey(), frames);
                }
                result.put(anim.getKey(), new BikeAnimation(
                        json.get("length").getAsFloat(), json.get("loop").getAsBoolean(), bones));
            }
        } catch (IOException | RuntimeException e) {
            throw new IllegalStateException("Failed to load animations " + location, e);
        }
        return result;
    }

    private static float[][] readFrames(JsonArray array) {
        float[][] frames = new float[array.size()][];
        for (int i = 0; i < frames.length; i++) {
            JsonArray frame = array.get(i).getAsJsonArray();
            frames[i] = new float[frame.size()];
            for (int j = 0; j < frame.size(); j++) {
                frames[i][j] = frame.get(j).getAsFloat();
            }
        }
        return frames;
    }

    /** Writes the interpolated value into {@code out}; returns false if the bone has no such channel. */
    public boolean sample(String bone, int channel, float time, float[] out) {
        float[][][] channels = this.bones.get(bone);
        if (channels == null || channels[channel] == null || channels[channel].length == 0) {
            return false;
        }
        float[][] frames = channels[channel];
        float t = this.loop && this.length > 0
                ? ((time % this.length) + this.length) % this.length
                : Mth.clamp(time, 0.0F, this.length);

        int next = 0;
        while (next < frames.length && frames[next][0] <= t) {
            next++;
        }
        if (next == 0 || next == frames.length) {
            float[] frame = frames[next == 0 ? 0 : frames.length - 1];
            System.arraycopy(frame, 1, out, 0, 3);
            return true;
        }
        float[] a = frames[next - 1];
        float[] b = frames[next];
        float k = a[4] != 0 ? 0 : (t - a[0]) / (b[0] - a[0]);
        for (int i = 0; i < 3; i++) {
            out[i] = a[i + 1] + (b[i + 1] - a[i + 1]) * k;
        }
        return true;
    }
}
