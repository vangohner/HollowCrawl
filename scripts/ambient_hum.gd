extends AudioStreamPlayer

@export var hum_frequency_hz: float = 65.0
@export var modulation_frequency_hz: float = 0.45
@export var modulation_depth: float = 0.25

var _generator: AudioStreamGenerator
var _mix_rate: float = 44100.0
var _phase: float = 0.0
var _modulation_phase: float = 0.0

func _ready() -> void:
    _generator = AudioStreamGenerator.new()
    _generator.mix_rate = _mix_rate
    _generator.buffer_length = 0.35
    stream = _generator
    volume_db = -12.0
    play()
    set_process(true)

func _process(delta: float) -> void:
    var playback := get_stream_playback()
    if playback == null:
        return
    var generator_playback := playback as AudioStreamGeneratorPlayback
    if generator_playback == null:
        return
    var frames_available: int = generator_playback.get_frames_available()
    if frames_available <= 0:
        return
    var phase_step: float = (TAU * hum_frequency_hz) / _mix_rate
    var mod_step: float = (TAU * modulation_frequency_hz) / _mix_rate
    for i in range(frames_available):
        var base_sample: float = sin(_phase)
        _phase = fposmod(_phase + phase_step, TAU)
        var modulation: float = 1.0 - modulation_depth + sin(_modulation_phase) * modulation_depth
        _modulation_phase = fposmod(_modulation_phase + mod_step, TAU)
        var sample: float = base_sample * modulation
        generator_playback.push_frame(Vector2(sample, sample))
