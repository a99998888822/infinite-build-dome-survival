@tool
extends EditorPlugin

var _android_export: TapTapAndroidExport


func _enter_tree() -> void:
	_android_export = TapTapAndroidExport.new()
	add_export_plugin(_android_export)


func _exit_tree() -> void:
	remove_export_plugin(_android_export)
	_android_export = null


class TapTapAndroidExport extends EditorExportPlugin:
	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid


	func _get_name() -> String:
		return "TapTapGodot"


	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["res://addons/taptap/bin/taptap-godot.aar"])


	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([
			"com.taptap.sdk:tap-core:4.11.0",
			"com.taptap.sdk:tap-login:4.11.0",
			"com.taptap.sdk:tap-compliance:4.11.0",
		])
