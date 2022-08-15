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
	 * @param	newWindow         The camera you want to add.
	 * @return	This FlxWindow instance.
	 */
	public function add<T:FlxWindow>(newWindow:T):T
	{
		if (!_cleanupCbkRegistered)
		{
			FlxG.game.stage.window.onClose.add(handleClose, false, 0);
			_cleanupCbkRegistered = true;
		}

		newWindow.window.stage.addChild(newWindow);

		list.push(newWindow);

		// newWindow.ID = list.length - 1;
		return newWindow;
	}

	function get_numWindows()
	{
		return list.length;
	}

	/**
	 * Remove a camera from the game.
	 *
	 * @param   window    The window you want to remove.
	 */
	public function remove(window:FlxWindow, destroy:Bool = true):Void
	{
		var index:Int = list.indexOf(window);
		if (window != null && index != -1)
		{
			window.window.stage.removeChild(window);
			list.remove(window);
		}
		else
		{
			FlxG.log.warn("FlxWindowManager.remove(): The window you attempted to remove is unknown.");
			return;
		}

		if (destroy)
			window.destroy();
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
			list[0].window.close();
		}
	}
}
