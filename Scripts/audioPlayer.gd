extends Node2D

class_name audioContainerNode

func playSound(name:String):
	var soundObject:AudioStreamPlayer2D = find_child(name)
	if !soundObject.playing: soundObject.play()
