package flixel;

/**
 * Accessed via `FlxG.windows`.
 */
class FlxWindowManager
{
	public var list(default, null):Array<FlxWindow>;

	public var numWindows(get, null):Int;

	var _cleanupCbkRegistered:Bool = false;

	/**
	 * Add a new window object to the game.
	 * @see flixel.FlxWindow
	 *
	 * @param	NewWindow         The camera you want to add.
	 * @return	This FlxWindow instance.
	 */
	public function add<T:FlxWindow>(NewWindow:T):T
	{
		if (!_cleanupCbkRegistered)
		{
			FlxG.game.stage.window.onClose.add(handleClose, false, 0);
			_cleanupCbkRegistered = true;
		}

		NewWindow._win.stage.addChild(NewWindow);

		list.push(NewWindow);

		// NewWindow.ID = list.length - 1;
		return NewWindow;
	}

	function get_numWindows()
	{
		return list.length;
	}

	/**
	 * Remove a camera from the game.
	 *
	 * @param   Window    The camera you want to remove.
	 * @param   Destroy   Whether to call destroy() on the camera, default value is true.
	 */
	public function remove(Window:FlxWindow):Void
	{
		var index:Int = list.indexOf(Window);
		trace('index=${index}');
		if (Window != null && index != -1)
		{
			trace('about to remove window');
			Window._win.stage.removeChild(Window);
			trace('removing window from list');
			list.remove(Window);
		}
		else
		{
			FlxG.log.warn("FlxG.windows.remove(): The window you attempted to remove is not a part of the game.");
			return;
		}

		// FIXME - not sure what this should be yet
		// if (Destroy)
		// 	Window.destroy();
	}

	@:allow(flixel.FlxG)
	function new()
	{
		list = new Array<FlxWindow>();
	}

	/**
	 * Delete all the windows if the main FlxGame window closes.
	 */
	function handleClose():Void
	{
		while (list.length > 0)
		{
			list[0]._win.close();
		}
	}
}
