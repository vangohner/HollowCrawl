extends AudioStreamPlayer3D

class_name FootstepPlayer

@export var step_length: float = 0.22
@export var step_pitch_hz: float = 110.0
@export var pitch_variation: float = 0.2
@export var noise_level: float = 0.25
@export var volume: float = 3.5
@export var thump_strength: float = 0.6

var _generator: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback
var _mix_rate: float = 44100.0

func _ready() -> void:
    _generator = AudioStreamGenerator.new()
    _generator.mix_rate = _mix_rate
    _generator.buffer_length = 0.35
    stream = _generator
    volume_db = volume
    attenuation_filter_cutoff_hz = 1600.0
    attenuation_filter_db = -1.0

func play_step(intensity: float) -> void:
    intensity = clampf(intensity, 0.2, 1.0)
    if not playing:
        play()
    if _playback == null:
        _playback = get_stream_playback() as AudioStreamGeneratorPlayback
    if _playback == null:
        return
    var frames_needed: int = int(step_length * _mix_rate)
    var frames_available: int = _playback.get_frames_available()
    if frames_available < frames_needed:
        return
    var phase: float = 0.0
    var phase_step: float = (TAU * step_pitch_hz * randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)) / _mix_rate
    var impact_frames: int = int(frames_needed * 0.22)
    for i in range(frames_needed):
        var t: float = float(i) / float(frames_needed)
        var envelope: float = sin(t * PI)
        var tonal: float = sin(phase)
        phase = fposmod(phase + phase_step, TAU)
        var noise: float = (randf() * 2.0 - 1.0) * noise_level
        var thump: float = 0.0
        if i < impact_frames:
            var impact_t: float = float(i) / float(max(impact_frames, 1))
            thump = (1.0 - impact_t) * thump_strength
        var sample: float = ((tonal * 0.55) + (noise * 0.45) + thump) * envelope * intensity * 1.4
        _playback.push_frame(Vector2(sample, sample))

func stop_steps() -> void:
    if playing:
        stop()
    if _playback:
        _playback.clear_buffer()
