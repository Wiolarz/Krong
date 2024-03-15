extends Control

@export var adress = "204.48.28.159"
@export var port = 8910
var peer


func _ready():
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)
	if "--server" in OS.get_cmdline_args():
		hostGame()
	pass # Replace with function body.


# this get called on the server and clients
func peer_connected(id):
	print("Player Connected " + str(id))
	
# this get called on the server and clients
func peer_disconnected(id):
	print("Player Disconnected " + str(id))
	BUS.connected_players.erase(id)
	var players = get_tree().get_nodes_in_group("Player")
	for i in players:
		if i.name == str(id):
			i.queue_free()
# called only from clients
func connected_to_server():
	print("connected To Sever!")
	SendPlayerInformation.rpc_id(1, $LineEdit.text, multiplayer.get_unique_id())

# called only from clients
func connection_failed():
	print("Couldnt Connect")

@rpc("any_peer")
func SendPlayerInformation(name, id):
	if !BUS.connected_players.has(id):
		BUS.connected_players[id] ={
			"name" : name,
			"id" : id,
			"score": 0
		}
	
	if multiplayer.is_server():
		for i in BUS.connected_players:
			SendPlayerInformation.rpc(BUS.connected_players[i].name, i)

@rpc("any_peer","call_local")
func StartGame():
	var scene = load("res://testScene.tscn").instantiate()
	get_tree().root.add_child(scene)
	self.hide()
	
func hostGame():
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, 2)
	if error != OK:
		print("cannot host: " + error)
		return
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	
	multiplayer.set_multiplayer_peer(peer)
	print("Waiting For connected_players!")
	
	
func _on_host_button_down():
	hostGame()
	SendPlayerInformation($LineEdit.text, multiplayer.get_unique_id())


func _on_join_button_down():
	peer = ENetMultiplayerPeer.new()
	peer.create_client(adress, port)
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)	


func _on_start_game_button_down():
	StartGame.rpc()
	