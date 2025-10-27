extends AudioStreamPlayer3D

@export var breath_duration: float = 1.2
@export var tone_frequency_hz: float = 180.0
@export var noise_amount: float = 0.45

var _generator: AudioStreamGenerator
var _mix_rate: float = 44100.0
var _phase: float = 0.0
var _frames_written: int = 0
var _total_frames: int = 0
var _playback: AudioStreamGeneratorPlayback

func _ready() -> void:
    _generator = AudioStreamGenerator.new()
    _generator.mix_rate = _mix_rate
    _generator.buffer_length = 0.5
    stream = _generator
    attenuation_filter_cutoff_hz = 1400.0
    volume_db = -10.0
    set_process(true)

func play(from_position: float = 0.0) -> void:
    _total_frames = int(breath_duration * _mix_rate)
    _frames_written = 0
    _phase = 0.0
    .play(from_position)
    _playback = get_stream_playback() as AudioStreamGeneratorPlayback
    if _playback:
        _playback.clear_buffer()

func stop() -> void:
    .stop()
    _frames_written = 0
    _total_frames = 0
    if _playback:
        _playback.clear_buffer()

func _process(delta: float) -> void:
    if _total_frames <= 0:
        return
    if _playback == null:
        _playback = get_stream_playback() as AudioStreamGeneratorPlayback
        if _playback == null:
            return
    var frames_available: int = min(_playback.get_frames_available(), _total_frames - _frames_written)
    if frames_available <= 0:
        return
    var phase_step: float = (TAU * tone_frequency_hz) / _mix_rate
    for i in range(frames_available):
        var progress: float = float(_frames_written) / float(_total_frames)
        var envelope: float = sin(progress * PI)
        var tonal: float = sin(_phase) * 0.35
        _phase = fposmod(_phase + phase_step, TAU)
        var noise: float = (randf() * 2.0 - 1.0) * noise_amount
        var sample: float = (tonal + noise) * envelope
        _playback.push_frame(Vector2(sample, sample))
        _frames_written += 1
    if _frames_written >= _total_frames:
        _total_frames = 0
