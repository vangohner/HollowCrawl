extends Node3D

class_name StalkerLeg

@export var upper_length: float = 0.9
@export var lower_length: float = 0.9
@export var step_phase: float = 0.0
@export var foot_home_offset: Vector3 = Vector3.ZERO

@onready var pivot: Node3D = $Pivot
@onready var upper: Node3D = $Pivot/Upper
@onready var lower: Node3D = $Pivot/Upper/Lower
@onready var foot: Node3D = $Pivot/Upper/Lower/Foot

func get_world_home_position(body_xform: Transform3D) -> Vector3:
    return body_xform.origin + body_xform.basis * foot_home_offset
