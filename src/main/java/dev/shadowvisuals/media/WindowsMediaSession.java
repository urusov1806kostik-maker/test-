package dev.shadowvisuals.media;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Base64;
import java.util.List;
import java.util.Locale;

import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParseException;
import com.google.gson.JsonParser;

import dev.shadowvisuals.core.Log;

/**
 * Reads the Windows "System Media Transport Controls" session (what the media flyout shows: Spotify, browsers,
 * Yandex Music, Windows Media Player...) through a small Windows PowerShell helper that uses the WinRT
 * {@code GlobalSystemMediaTransportControlsSessionManager} API and prints one JSON line per poll.
 *
 * <p>The helper is started once, read on a daemon thread, restarted with growing delays if it dies, and
 * exits by itself when the game process is gone, so it can never outlive Minecraft. No native libraries and
 * no admin rights are needed. Windows PowerShell 5.1 is used on purpose: PowerShell 7 cannot load WinRT types.
 */
public final class WindowsMediaSession implements MediaSource {
	private static final long POLL_MILLIS = 700;
	private static final long MAX_RESTART_DELAY_MILLIS = 60_000;

	private volatile Status status = Status.STARTING;
	private volatile MediaInfo current;
	private volatile boolean running;
	private Thread worker;
	private Process process;

	public static boolean isSupported() {
		return System.getProperty("os.name", "").toLowerCase(Locale.ROOT).startsWith("windows");
	}

	@Override
	public synchronized void start() {
		if (running) {
			return;
		}
		if (!isSupported()) {
			status = Status.UNSUPPORTED;
			return;
		}
		running = true;
		status = Status.STARTING;
		worker = new Thread(this::run, "Shadow Visuals media session");
		worker.setDaemon(true);
		worker.start();
	}

	@Override
	public Status status() {
		return status;
	}

	@Override
	public MediaInfo current() {
		return current;
	}

	private void run() {
		long delay = 2000;
		while (running) {
			long started = System.currentTimeMillis();
			try {
				readFromHelper();
			} catch (IOException e) {
				Log.warnOnce("media-session-io", "Media session helper failed: {}", e.toString());
			}
			current = null;
			if (!running) {
				break;
			}
			// A helper that ran for a while is restarted quickly; one that keeps dying backs off.
			delay = System.currentTimeMillis() - started > 30_000 ? 2000 : Math.min(MAX_RESTART_DELAY_MILLIS, delay * 2);
			status = Status.FAILED;
			try {
				Thread.sleep(delay);
			} catch (InterruptedException e) {
				Thread.currentThread().interrupt();
				return;
			}
		}
	}

	private void readFromHelper() throws IOException {
		Process started = new ProcessBuilder(command())
			.redirectError(ProcessBuilder.Redirect.DISCARD)
			.redirectInput(ProcessBuilder.Redirect.PIPE)
			.start();
		synchronized (this) {
			if (!running) {
				started.destroy();
				return;
			}
			process = started;
		}
		try (BufferedReader reader = new BufferedReader(new InputStreamReader(started.getInputStream(), StandardCharsets.UTF_8))) {
			String line;
			while (running && (line = reader.readLine()) != null) {
				MediaInfo parsed = parse(line);
				if (parsed != NO_LINE) {
					current = parsed;
					status = Status.RUNNING;
				}
			}
		} finally {
			started.destroy();
		}
	}

	/** Marker for lines that are not session data (helper noise); distinct from "nothing playing" (null). */
	private static final MediaInfo NO_LINE = new MediaInfo("", "", "", "", false, 0, 0, 0);

	/** Parses one helper line; {@code null} means no session, {@link #NO_LINE} means "ignore this line". */
	static MediaInfo parse(String line) {
		if (line == null || !line.startsWith("{")) {
			return NO_LINE;
		}
		try {
			JsonElement element = JsonParser.parseString(line);
			if (!element.isJsonObject()) {
				return NO_LINE;
			}
			JsonObject json = element.getAsJsonObject();
			if (!"ok".equals(string(json, "state"))) {
				return null;
			}
			MediaInfo info = new MediaInfo(string(json, "title"), string(json, "artist"), string(json, "album"), string(json, "app"),
				"Playing".equalsIgnoreCase(string(json, "status")), (long) number(json, "position"), (long) number(json, "duration"),
				(long) number(json, "updated"));
			return info.hasTrack() ? info : null;
		} catch (JsonParseException | IllegalStateException | UnsupportedOperationException e) {
			return NO_LINE;
		}
	}

	private static String string(JsonObject json, String key) {
		JsonElement value = json.get(key);
		return value != null && value.isJsonPrimitive() ? value.getAsString() : "";
	}

	private static double number(JsonObject json, String key) {
		JsonElement value = json.get(key);
		if (value == null || !value.isJsonPrimitive() || !value.getAsJsonPrimitive().isNumber()) {
			return 0;
		}
		double number = value.getAsDouble();
		return Double.isFinite(number) && number > 0 ? number : 0;
	}

	private static List<String> command() {
		String root = System.getenv("SystemRoot");
		Path shell = root == null ? null : Path.of(root, "System32", "WindowsPowerShell", "v1.0", "powershell.exe");
		String executable = shell != null && Files.isRegularFile(shell) ? shell.toString() : "powershell.exe";
		String script = SCRIPT.replace("%PARENT%", Long.toString(ProcessHandle.current().pid()))
			.replace("%POLL%", Long.toString(POLL_MILLIS));
		String encoded = Base64.getEncoder().encodeToString(script.getBytes(StandardCharsets.UTF_16LE));
		return List.of(executable, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden",
			"-EncodedCommand", encoded);
	}

	@Override
	public void close() {
		Process toStop;
		synchronized (this) {
			running = false;
			toStop = process;
			process = null;
			if (worker != null) {
				worker.interrupt();
				worker = null;
			}
		}
		if (toStop != null) {
			toStop.descendants().forEach(ProcessHandle::destroy);
			toStop.destroy();
		}
		current = null;
		status = isSupported() ? Status.STARTING : Status.UNSUPPORTED;
	}

	/**
	 * Polls the media session manager and prints compact JSON. Prefers a session that is actually playing over
	 * the system's "current" one, and stops when the parent process (the game) no longer exists.
	 */
	private static final String SCRIPT = """
		$ErrorActionPreference = 'Stop'
		[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
		Add-Type -AssemblyName System.Runtime.WindowsRuntime
		$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
			$_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
		})[0]
		function Await($operation, [Type]$type) {
			$task = $asTask.MakeGenericMethod($type).Invoke($null, @($operation))
			$task.Wait(-1) | Out-Null
			$task.Result
		}
		$managerType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media.Control,ContentType=WindowsRuntime]
		$propertiesType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties,Windows.Media.Control,ContentType=WindowsRuntime]
		$manager = Await ($managerType::RequestAsync()) $managerType
		while ($true) {
			if (-not (Get-Process -Id %PARENT% -ErrorAction SilentlyContinue)) { break }
			try {
				$session = $null
				foreach ($candidate in $manager.GetSessions()) {
					if ($candidate.GetPlaybackInfo().PlaybackStatus -eq 'Playing') { $session = $candidate; break }
				}
				if ($session -eq $null) { $session = $manager.GetCurrentSession() }
				if ($session -eq $null) {
					[Console]::Out.WriteLine('{"state":"none"}')
				} else {
					$properties = Await ($session.TryGetMediaPropertiesAsync()) $propertiesType
					$timeline = $session.GetTimelineProperties()
					$info = [ordered]@{
						state = 'ok'
						title = [string]$properties.Title
						artist = [string]$properties.Artist
						album = [string]$properties.AlbumTitle
						app = [string]$session.SourceAppUserModelId
						status = [string]$session.GetPlaybackInfo().PlaybackStatus
						position = [double]$timeline.Position.TotalMilliseconds
						duration = [double]$timeline.EndTime.TotalMilliseconds
						updated = [double]$timeline.LastUpdatedTime.ToUnixTimeMilliseconds()
					}
					[Console]::Out.WriteLine(($info | ConvertTo-Json -Compress))
				}
			} catch {
				[Console]::Out.WriteLine('{"state":"error"}')
			}
			[Console]::Out.Flush()
			Start-Sleep -Milliseconds %POLL%
		}
		""";
}
