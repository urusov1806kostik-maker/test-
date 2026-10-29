package dev.nyxveravisuals.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

import net.minecraft.client.multiplayer.ClientLevel;
import net.minecraft.world.level.Level;

import dev.nyxveravisuals.modules.Hooks;
import dev.nyxveravisuals.modules.world.WeatherControl;

/** Weather Control: only the client level is affected; server levels keep their real weather. */
@Mixin(Level.class)
public abstract class LevelMixin {
	@Inject(method = "getRainLevel", at = @At("HEAD"), cancellable = true)
	private void nyxveravisuals$rain(float partialTick, CallbackInfoReturnable<Float> cir) {
		if ((Object) this instanceof ClientLevel) {
			WeatherControl weather = Hooks.enabled(WeatherControl.class);
			if (weather != null) {
				cir.setReturnValue(weather.rainLevel());
			}
		}
	}

	@Inject(method = "getThunderLevel", at = @At("HEAD"), cancellable = true)
	private void nyxveravisuals$thunder(float partialTick, CallbackInfoReturnable<Float> cir) {
		if ((Object) this instanceof ClientLevel) {
			WeatherControl weather = Hooks.enabled(WeatherControl.class);
			if (weather != null) {
				cir.setReturnValue(weather.thunderLevel());
			}
		}
	}
}
