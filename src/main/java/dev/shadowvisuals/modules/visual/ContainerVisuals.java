package dev.shadowvisuals.modules.visual;

import java.util.ArrayList;
import java.util.List;

import net.minecraft.client.Minecraft;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.block.entity.AbstractFurnaceBlockEntity;
import net.minecraft.world.level.block.entity.BarrelBlockEntity;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.entity.ChestBlockEntity;
import net.minecraft.world.level.block.entity.DispenserBlockEntity;
import net.minecraft.world.level.block.entity.EnderChestBlockEntity;
import net.minecraft.world.level.block.entity.HopperBlockEntity;
import net.minecraft.world.level.block.entity.ShulkerBoxBlockEntity;
import net.minecraft.world.level.block.entity.TrappedChestBlockEntity;
import net.minecraft.world.level.chunk.LevelChunk;
import net.minecraft.world.level.chunk.status.ChunkStatus;
import net.minecraft.world.phys.AABB;

import dev.shadowvisuals.event.events.ClientTickEvent;
import dev.shadowvisuals.event.events.WorldLeaveEvent;
import dev.shadowvisuals.event.events.WorldRenderEvent;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.render.WorldRenderer3D;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.setting.ColorSetting;
import dev.shadowvisuals.setting.IntSetting;
import dev.shadowvisuals.setting.MultiSelectSetting;
import dev.shadowvisuals.setting.SettingGroup;
import dev.shadowvisuals.util.ColorUtil;

/**
 * Highlights storage blocks with per-type colors. Loaded chunks around the player are rescanned twice a
 * second into a bounded cache; rendering only walks that cache. Everything is client-side.
 */
public final class ContainerVisuals extends Module {
	public enum Type {
		CHEST,
		TRAPPED_CHEST,
		ENDER_CHEST,
		SHULKER_BOX,
		BARREL,
		HOPPER,
		DISPENSER,
		FURNACE
	}

	private record Entry(BlockPos pos, Type type) {
	}

	private static final int MAX_ENTRIES = 2048;

	private final MultiSelectSetting<Type> types = settings().add(new MultiSelectSetting<>("types", Type.class,
		Type.CHEST, Type.TRAPPED_CHEST, Type.ENDER_CHEST, Type.SHULKER_BOX, Type.BARREL));
	private final IntSetting radius = settings().add(new IntSetting("chunk_radius", 6, 1, 12));
	private final BooleanSetting fill = settings().add(new BooleanSetting("fill", true));
	private final BooleanSetting throughWalls = settings().add(new BooleanSetting("through_walls", false));
	private final SettingGroup colors = settings().add(new SettingGroup("colors", false));
	private final ColorSetting chestColor = settings().add(colors, new ColorSetting("chest_color", 0xFFF5B544, false));
	private final ColorSetting trappedColor = settings().add(colors, new ColorSetting("trapped_chest_color", 0xFFF2555A, false));
	private final ColorSetting enderColor = settings().add(colors, new ColorSetting("ender_chest_color", 0xFFB07CF6, false));
	private final ColorSetting shulkerColor = settings().add(colors, new ColorSetting("shulker_box_color", 0xFFF27BC9, false));
	private final ColorSetting barrelColor = settings().add(colors, new ColorSetting("barrel_color", 0xFFC98B4F, false));
	private final ColorSetting hopperColor = settings().add(colors, new ColorSetting("hopper_color", 0xFF9AA3B5, false));
	private final ColorSetting dispenserColor = settings().add(colors, new ColorSetting("dispenser_color", 0xFF7F8794, false));
	private final ColorSetting furnaceColor = settings().add(colors, new ColorSetting("furnace_color", 0xFFE07A3F, false));
	private List<Entry> entries = List.of();
	private int ticks;

	public ContainerVisuals() {
		super("container_visuals", Category.VISUAL);
		on(ClientTickEvent.class, event -> {
			if (!event.isPre() && ticks++ % 10 == 0) {
				rescan();
			}
		});
		on(WorldLeaveEvent.class, event -> entries = List.of());
		on(WorldRenderEvent.class, this::render);
	}

	@Override
	protected void onEnable() {
		ticks = 0;
	}

	@Override
	protected void onDisable() {
		entries = List.of();
	}

	private static Type typeOf(BlockEntity blockEntity) {
		if (blockEntity instanceof TrappedChestBlockEntity) {
			return Type.TRAPPED_CHEST;
		}
		if (blockEntity instanceof ChestBlockEntity) {
			return Type.CHEST;
		}
		if (blockEntity instanceof EnderChestBlockEntity) {
			return Type.ENDER_CHEST;
		}
		if (blockEntity instanceof ShulkerBoxBlockEntity) {
			return Type.SHULKER_BOX;
		}
		if (blockEntity instanceof BarrelBlockEntity) {
			return Type.BARREL;
		}
		if (blockEntity instanceof HopperBlockEntity) {
			return Type.HOPPER;
		}
		if (blockEntity instanceof DispenserBlockEntity) {
			return Type.DISPENSER;
		}
		if (blockEntity instanceof AbstractFurnaceBlockEntity) {
			return Type.FURNACE;
		}
		return null;
	}

	private void rescan() {
		Minecraft minecraft = Minecraft.getInstance();
		if (minecraft.level == null || minecraft.player == null) {
			entries = List.of();
			return;
		}
		List<Entry> found = new ArrayList<>();
		int centerX = minecraft.player.blockPosition().getX() >> 4;
		int centerZ = minecraft.player.blockPosition().getZ() >> 4;
		int r = radius.getInt();
		for (int cx = centerX - r; cx <= centerX + r && found.size() < MAX_ENTRIES; cx++) {
			for (int cz = centerZ - r; cz <= centerZ + r && found.size() < MAX_ENTRIES; cz++) {
				LevelChunk chunk = minecraft.level.getChunkSource().getChunk(cx, cz, ChunkStatus.FULL, false);
				if (chunk == null) {
					continue;
				}
				for (BlockEntity blockEntity : chunk.getBlockEntities().values()) {
					Type type = typeOf(blockEntity);
					if (type != null && types.contains(type)) {
						found.add(new Entry(blockEntity.getBlockPos(), type));
						if (found.size() >= MAX_ENTRIES) {
							break;
						}
					}
				}
			}
		}
		entries = found;
	}

	private int color(Type type) {
		return switch (type) {
			case CHEST -> chestColor.color();
			case TRAPPED_CHEST -> trappedColor.color();
			case ENDER_CHEST -> enderColor.color();
			case SHULKER_BOX -> shulkerColor.color();
			case BARREL -> barrelColor.color();
			case HOPPER -> hopperColor.color();
			case DISPENSER -> dispenserColor.color();
			case FURNACE -> furnaceColor.color();
		};
	}

	private void render(WorldRenderEvent event) {
		for (Entry entry : entries) {
			BlockPos pos = entry.pos();
			boolean chestShape = entry.type() == Type.CHEST || entry.type() == Type.TRAPPED_CHEST || entry.type() == Type.ENDER_CHEST;
			double inset = chestShape ? 0.0625 : 0.0;
			AABB box = new AABB(pos.getX() + inset, pos.getY(), pos.getZ() + inset, pos.getX() + 1 - inset, pos.getY() + (chestShape ? 0.875 : 1), pos.getZ() + 1 - inset);
			int argb = color(entry.type());
			if (fill.get()) {
				WorldRenderer3D.boxFilled(event.frame(), box, ColorUtil.withAlpha(argb, 40), throughWalls.get());
			}
			WorldRenderer3D.boxOutline(event.frame(), box, ColorUtil.withAlpha(argb, 220), 1.6f, throughWalls.get());
		}
	}
}
