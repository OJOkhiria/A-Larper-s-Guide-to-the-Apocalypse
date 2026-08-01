extends Control

@onready var conclusion_song: AudioStreamPlayer = $ConclusionSong
@onready var return_button: Button = get_node_or_null(
	"Book/RightPage/MarginContainer/ReturnToTitle"
)


func _ready() -> void:
	# The conclusion begins with the same book already open; there is no
	# introductory fall, cover animation, or book-thud sound.
	conclusion_song.play()
	if return_button != null:
		return_button.pressed.connect(_return_to_title)


func _return_to_title() -> void:
	if return_button != null:
		return_button.disabled = true
	LvlManager.load_main_menu()
