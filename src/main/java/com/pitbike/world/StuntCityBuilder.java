package com.pitbike.world;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.StairBlock;
import net.minecraft.world.level.block.state.BlockState;

/**
 * Builds a small stunt city: a 3x3 grid of blocks separated by roads.
 * <pre>
 *  z\x   0             1               2
 *  0   park         rooftop ramp ->  landing roof
 *  1   tower        skate plaza      building
 *  2   start zone   mega ramp ->     landing ramp
 * </pre>
 * Local coordinates: x/z from the north-west corner, y = 0 is the street surface.
 */
public final class StuntCityBuilder {
    public static final int SIZE = 92;
    private static final int ROAD = 8;
    private static final int BLOCK = 20;
    private static final int PITCH = ROAD + BLOCK;
    private static final int SIDEWALK = 2;
    private static final int INNER = BLOCK - 2 * SIDEWALK;
    private static final int CLEAR_HEIGHT = 40;

    private static final BlockState AIR = Blocks.AIR.defaultBlockState();
    private static final BlockState ASPHALT = Blocks.BLACK_CONCRETE.defaultBlockState();
    private static final BlockState LINE = Blocks.YELLOW_CONCRETE.defaultBlockState();
    private static final BlockState PAVEMENT = Blocks.SMOOTH_STONE.defaultBlockState();
    private static final BlockState RAMP = Blocks.STONE_BRICKS.defaultBlockState();
    private static final BlockState RAMP_STAIRS = Blocks.STONE_BRICK_STAIRS.defaultBlockState();
    private static final BlockState RAMP_SLAB = Blocks.STONE_BRICK_SLAB.defaultBlockState();
    private static final BlockState ROOF = Blocks.SMOOTH_STONE.defaultBlockState();
    private static final BlockState WINDOW = Blocks.LIGHT_BLUE_STAINED_GLASS.defaultBlockState();

    private final ServerLevel level;
    private final BlockPos origin;

    private StuntCityBuilder(ServerLevel level, BlockPos origin) {
        this.level = level;
        this.origin = origin;
    }

    /** Builds the city with its north-west street corner at {@code origin}. */
    public static void build(ServerLevel level, BlockPos origin) {
        new StuntCityBuilder(level, origin).build();
    }

    /** Where to start: on the west road, facing east towards the mega ramp. */
    public static BlockPos startPoint(BlockPos origin) {
        return origin.offset(3, 1, blockStart(2) + SIDEWALK + 7);
    }

    private static int blockStart(int index) {
        return ROAD + index * PITCH;
    }

    private void build() {
        this.fill(0, 1, 0, SIZE - 1, CLEAR_HEIGHT, SIZE - 1, AIR);
        this.fill(0, -2, 0, SIZE - 1, -1, SIZE - 1, Blocks.STONE.defaultBlockState());
        this.fill(0, 0, 0, SIZE - 1, 0, SIZE - 1, ASPHALT);
        this.roadMarkings();

        for (int i = 0; i < 3; i++) {
            for (int j = 0; j < 3; j++) {
                int bx = blockStart(i);
                int bz = blockStart(j);
                this.fill(bx, 0, bz, bx + BLOCK - 1, 0, bz + BLOCK - 1, PAVEMENT);
                this.streetLight(bx, bz);
                this.streetLight(bx + BLOCK - 1, bz);
                this.streetLight(bx, bz + BLOCK - 1);
                this.streetLight(bx + BLOCK - 1, bz + BLOCK - 1);
            }
        }

        // Blocks are filled through their inner 16x16 area.
        this.park(inner(0), inner(0));
        this.rooftopRamp(inner(1), inner(0));
        this.landingRoof(inner(2), inner(0));
        this.building(inner(0), inner(1), INNER, INNER, 20, Blocks.WHITE_CONCRETE.defaultBlockState(), true);
        this.skatePlaza(inner(1), inner(1));
        this.building(inner(2), inner(1), INNER, INNER, 8, Blocks.ORANGE_CONCRETE.defaultBlockState(), true);
        this.startZone(inner(0), inner(2));
        this.megaRamp(inner(1), inner(2));
        this.landingRamp(inner(2), inner(2));
    }

    private static int inner(int index) {
        return blockStart(index) + SIDEWALK;
    }

    // ---- Streets ----

    private void roadMarkings() {
        for (int road = 0; road < SIZE; road += PITCH) {
            for (int t = 0; t < SIZE; t++) {
                if (t % PITCH < ROAD || t % 6 >= 3) {
                    continue; // no markings in crossings, dashed elsewhere
                }
                for (int lane = ROAD / 2 - 1; lane <= ROAD / 2; lane++) {
                    this.set(t, 0, road + lane, LINE);
                    this.set(road + lane, 0, t, LINE);
                }
            }
        }
    }

    private void streetLight(int x, int z) {
        this.fill(x, 1, z, x, 3, z, Blocks.ANDESITE_WALL.defaultBlockState());
        this.set(x, 4, z, Blocks.LANTERN.defaultBlockState());
    }

    // ---- City blocks ----

    private void park(int x, int z) {
        this.fill(x, 0, z, x + INNER - 1, 0, z + INNER - 1, Blocks.GRASS_BLOCK.defaultBlockState());
        // Path lined up with the rooftop ramp next door.
        this.fill(x, 0, z + 4, x + INNER - 1, 0, z + 8, PAVEMENT);
        this.tree(x + 3, z + 13);
        this.tree(x + 8, z + 12);
        this.tree(x + 13, z + 13);
        this.tree(x + 5, z + 1);
        this.tree(x + 12, z + 1);
    }

    private void tree(int x, int z) {
        this.fill(x - 2, 4, z - 2, x + 2, 5, z + 2, Blocks.OAK_LEAVES.defaultBlockState());
        this.fill(x - 1, 6, z - 1, x + 1, 6, z + 1, Blocks.OAK_LEAVES.defaultBlockState());
        this.fill(x, 1, z, x, 5, z, Blocks.OAK_LOG.defaultBlockState());
    }

    /** Stairs up to a roof, a run-up across it and a kicker that jumps the road to the next roof. */
    private void rooftopRamp(int x, int z) {
        int roof = 6;
        this.stairsUp(x, z + 4, 5, 0, roof, Direction.EAST);
        this.building(x + roof, z, INNER - roof, INNER, roof, Blocks.PURPLE_CONCRETE.defaultBlockState(), false);
        this.stairsUp(x + INNER - 2, z + 4, 5, roof, 2, Direction.EAST);
    }

    /** Lower roof to land on, with stairs back down to the street. */
    private void landingRoof(int x, int z) {
        int roof = 5;
        this.building(x, z, INNER - roof, INNER, roof, Blocks.CYAN_CONCRETE.defaultBlockState(), false);
        this.stairsDown(x + INNER - roof, z + 4, 5, roof, Direction.EAST);
    }

    private void skatePlaza(int x, int z) {
        // Funbox: up, table, down.
        this.stairsUp(x, z + 6, 4, 0, 3, Direction.EAST);
        this.fill(x + 3, 1, z + 6, x + 9, 3, z + 9, RAMP);
        this.stairsDown(x + 10, z + 6, 4, 3, Direction.EAST);
        // Kickers in both directions and a steep quarter.
        this.stairsUp(x + 1, z + 13, 3, 0, 2, Direction.EAST);
        this.stairsUp(x + 13, z + 1, 3, 0, 2, Direction.WEST);
        this.stairsUp(x + 12, z + 13, 3, 0, 3, Direction.EAST);
    }

    private void startZone(int x, int z) {
        this.fill(x, 0, z, x + INNER - 1, 0, z + INNER - 1, PAVEMENT);
        for (int i = 0; i < INNER; i += 2) {
            this.set(x + i, 0, z + 4, LINE);
            this.set(x + i, 0, z + 10, LINE);
        }
    }

    /** Long 1:2 slope topped by a steep kicker; it jumps the road onto the landing ramp. */
    private void megaRamp(int x, int z) {
        int slope = INNER - 3;
        for (int k = 0; k < slope; k++) {
            this.slabColumn(x + k, z + 5, 5, k + 1);
        }
        this.stairsUp(x + slope, z + 5, 5, slope / 2, 3, Direction.EAST);
    }

    private void landingRamp(int x, int z) {
        // Starts on the sidewalk so the gap over the road stays jumpable.
        int length = INNER + SIDEWALK;
        for (int k = 0; k < length; k++) {
            this.slabColumn(x - SIDEWALK + k, z + 5, 5, length - k);
        }
        this.building(x, z + 12, INNER, INNER - 12, 4, Blocks.LIME_CONCRETE.defaultBlockState(), true);
    }

    // ---- Pieces ----

    /** Hollow building with windows; roof at {@code y = height}. */
    private void building(int x, int z, int w, int d, int height, BlockState wall, boolean parapet) {
        for (int y = 1; y <= height; y++) {
            for (int i = 0; i < w; i++) {
                for (int j = 0; j < d; j++) {
                    boolean edgeX = i == 0 || i == w - 1;
                    boolean edgeZ = j == 0 || j == d - 1;
                    BlockState state = AIR;
                    if (y == height) {
                        state = ROOF;
                    } else if (edgeX || edgeZ) {
                        int along = edgeX ? j : i;
                        boolean corner = edgeX && edgeZ;
                        state = !corner && y % 3 == 2 && along % 3 != 0 ? WINDOW : wall;
                    }
                    this.set(x + i, y, z + j, state);
                }
            }
        }
        this.fill(x + w / 2 - 1, 1, z, x + w / 2, 2, z, AIR);
        this.set(x + w / 2, height, z + d / 2, Blocks.GLOWSTONE.defaultBlockState());
        if (parapet) {
            for (int i = 0; i < w; i++) {
                this.set(x + i, height + 1, z, wall);
                this.set(x + i, height + 1, z + d - 1, wall);
            }
            for (int j = 0; j < d; j++) {
                this.set(x, height + 1, z + j, wall);
                this.set(x + w - 1, height + 1, z + j, wall);
            }
        }
    }

    /** {@code count} stairs climbing in {@code dir} from {@code base}, {@code width} wide (towards +z or +x). */
    private void stairsUp(int x, int z, int width, int base, int count, Direction dir) {
        for (int k = 0; k < count; k++) {
            int y = base + k + 1;
            for (int w = 0; w < width; w++) {
                int px = x + (dir.getAxis() == Direction.Axis.X ? (dir == Direction.EAST ? k : -k) : w);
                int pz = z + (dir.getAxis() == Direction.Axis.Z ? (dir == Direction.SOUTH ? k : -k) : w);
                this.fill(px, 1, pz, px, y - 1, pz, RAMP);
                this.set(px, y, pz, RAMP_STAIRS.setValue(StairBlock.FACING, dir));
            }
        }
    }

    /** Stairs going down from {@code height} while travelling in {@code dir}. */
    private void stairsDown(int x, int z, int width, int height, Direction dir) {
        for (int k = 0; k < height; k++) {
            int y = height - k;
            for (int w = 0; w < width; w++) {
                int px = x + (dir.getAxis() == Direction.Axis.X ? (dir == Direction.EAST ? k : -k) : w);
                int pz = z + (dir.getAxis() == Direction.Axis.Z ? (dir == Direction.SOUTH ? k : -k) : w);
                this.fill(px, 1, pz, px, y - 1, pz, RAMP);
                this.set(px, y, pz, RAMP_STAIRS.setValue(StairBlock.FACING, dir.getOpposite()));
            }
        }
    }

    /** A column of the given height in half blocks, {@code width} wide along z. */
    private void slabColumn(int x, int z, int width, int halves) {
        for (int w = 0; w < width; w++) {
            if (halves >= 2) {
                this.fill(x, 1, z + w, x, halves / 2, z + w, RAMP);
            }
            if (halves % 2 == 1) {
                this.set(x, halves / 2 + 1, z + w, RAMP_SLAB);
            }
        }
    }

    private void fill(int x1, int y1, int z1, int x2, int y2, int z2, BlockState state) {
        for (int x = x1; x <= x2; x++) {
            for (int y = y1; y <= y2; y++) {
                for (int z = z1; z <= z2; z++) {
                    this.set(x, y, z, state);
                }
            }
        }
    }

    private void set(int x, int y, int z, BlockState state) {
        this.level.setBlock(this.origin.offset(x, y, z), state, Block.UPDATE_CLIENTS);
    }
}
