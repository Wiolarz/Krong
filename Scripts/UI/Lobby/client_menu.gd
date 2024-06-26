class_name ClientMenu
extends Control


var client_connector_scene = \
	load("res://Scenes/UI/Lobby/Network/ClientConnector.tscn")
var client_server_chat_scene = \
	load("res://Scenes/UI/Lobby/Network/ClientServerChat.tscn")

@onready var multi_game_setup : GameSetup = $PanelContainer/GameSetup


@onready var connection_management = $ConnectionManagement


func go_back():
	IM.go_to_main_menu()


func clear_management():
	for child in connection_management.get_children():
		child.queue_free()


func show_client_connector():
	clear_management()
	var client_connector = client_connector_scene.instantiate()
	connection_management.add_child(client_connector)
	client_connector.name = "ClientConnector"
	client_connector.client_menu = self


func show_client_server_chat():
	clear_management()
	var client_server_chat = client_server_chat_scene.instantiate()
	connection_management.add_child(client_server_chat)
	client_server_chat.name = "ClientServerChat"


func _ready():
	show_client_connector()
	multi_game_setup.hide()


func _process(_delta : float):
	var client_connected : bool = NET.client_connection()
	if client_connected and \
			not connection_management.get_node_or_null("ClientServerChat"):
		show_client_server_chat()
		multi_game_setup.show()
	elif not client_connected and \
			not connection_management.get_node_or_null("ClientConnector"):
		show_client_connector()
		multi_game_setup.hide()
