package flixel;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.graphics.tile.FlxDrawBaseItem;
import flixel.system.frontEnds.CameraFrontEndWin;
import flixel.util.FlxColor;
import openfl.display.Sprite;
import openfl.display.StageAlign;
import openfl.display.StageScaleMode;
import openfl.events.Event;

/*
	TODO

	6. resize doesn't work - camera doesn't resize
	7. putting cameras from two windows on a sprite results in it rendering to the second one only
		The problem is that the texture is rendered using a shader via FlxDrawQuadsItem.render. The shader has a Context3D object which is specific to the window. So this needs to change for any sprite rendering to multiple windows, as the render switches from window to window. This requires access to the __context field of the openfl.display.Shader class. This a hack. The right way is probably to create a completely separate shader for each window rendering the sprite.
	8. focus is lost on the first window when clicking on others. Brining all windows to front is not easy without causing loops in the focus() behaviour
	9. When a non-main window is closed should all its cameras be removed from all sprites in the game ?
	10. onClose() does not cleanup any FlxSprite which has cameras from the window in their list of cameras.
	13. If you create windows in the initial PlayState.create() then we get a nasty exception
	14. when any window is brought into focus, all should be brought to front and the main window be given focus - this may change if a window should have focus, but will do for now.
	15. cursor should be visible in all windows - or at least be able to be - not all at once but whichever window the mouse is over
	16. Figure out how to get rid of CameraFrontEndWin.hx and just modify the regular CameraFrontEnd

 */
class FlxWindow extends Sprite
{
	public var _win:lime.ui.Window;

	@:allow(flixel.system.frontEnds.CameraFrontEndWin)
	@:allow(flixel.system.frontEnds.CameraFrontEnd)
	var _inputContainer:Sprite;

	var _width:Int;
	var _height:Int;
	var _initialX:Int;
	var _initialY:Int;

	public var windowName(default, null):String;

	/**
	 * Contains things related to cameras, a list of all cameras and several effects like `flash()` or `fade()`.
	 */
	public var cameras(default, null):CameraFrontEndWin;

	public var _camera:FlxCamera;

	/**
	 * Create a new window at x, y with size width and height.
	 * @param x 
	 * @param y 
	 * @param width 
	 * @param height 
	 */
	public static function createWindow(x:Int, y:Int, width:Int, height:Int, name:String, takeFocus:Bool):FlxWindow
	{
		var window = new FlxWindow(x, y, width, height, name);

		FlxG.windows.add(window);
		if (!takeFocus)
		{
			// Return focus to main game window
			FlxG.game.stage.window.focus();
		}
		return window;
	}

	function new(x:Int, y:Int, width:Int, height:Int, name:String)
	{
		super();

		trace('creating a flixel FlxWindow ${name}');
		_width = width;
		_height = height;
		_initialX = x;
		_initialY = y;
		windowName = name;

		_inputContainer = new Sprite();

		var attributes:lime.ui.WindowAttributes = {
			allowHighDPI: false,
			alwaysOnTop: false,
			borderless: false,
			// display: 0,
			element: null,
			frameRate: 60,
			#if !web
			fullscreen: false,
			#end
			height: _height,
			hidden: #if munit true #else false #end,
			maximized: false,
			minimized: false,
			parameters: {},
			resizable: true,
			title: windowName,
			width: _width,
			x: null,
			y: null
		};

		attributes.context = {
			antialiasing: 0,
			background: 0,
			colorDepth: 32,
			depth: true,
			hardware: true,
			stencil: true,
			type: null,
			vsync: false
		};
		_win = FlxG.stage.application.createWindow(attributes);
		_win.stage.color = FlxColor.ORANGE; // TODO remove - color only set for debugging
		_win.x = _initialX;
		_win.y = _initialY;

		addEventListener(Event.ADDED_TO_STAGE, create);
	}

	function create(_):Void
	{
		trace('create called stage=${stage}');
		var ctxSame = stage.context3D == FlxG.game.stage.context3D;
		trace('context3D matchs main window=${ctxSame}');
		removeEventListener(Event.ADDED_TO_STAGE, create);
		if (stage == null)
		{
			trace('stage is null');
			return;
		}

		trace('my stage is :');
		trace(stage);
		trace('render tile = ${FlxG.renderTile}');

		// Set up the view window and double buffering
		stage.scaleMode = StageScaleMode.NO_SCALE;
		stage.align = StageAlign.TOP_LEFT;
		stage.frameRate = FlxG.drawFramerate;

		// Add the window openFL Sprite to the stage
		addChild(_inputContainer);
		// Add camera openFL Sprite to the stage at the same place in the display list
		// Not sure if this before or after the _inputContainer
		// Setup the front end and default camera
		_camera = new FlxCamera(0, 0, _width, _height);
		_camera.bgColor = FlxColor.PINK;
		cameras = new CameraFrontEndWin(this);
		cameras.add(_camera);

		// addChildAt(_camera.flashSprite, getChildIndex(_inputContainer));

		addEventListener(Event.DEACTIVATE, onFocusLost);
		addEventListener(Event.ACTIVATE, onFocus);

		// stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
		// We need to listen for resize event which means new context
		// it means that we need to recreate BitmapDatas of dumped tilesheets
		addEventListener(Event.RESIZE, onResize);
		stage.window.onClose.add(onClose, false, 0);

		stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
	}

	function onEnterFrame(_):Void
	{
		FlxG.renderingWindow = this;
		FlxG.game.draw();

		// FlxG.game.onEnterFrameFromWindow(_);
		FlxG.renderingWindow = null;
	}

	public function addCamera(camera:FlxCamera, DefaultDrawTarget:Bool = true):Void
	{
		cameras.add(camera);
	}

	/**
	 * Remove the window from the window manager when it is closed.
	 * TODO - this does not cleanup any FlxSprite which have cameras from the window in their list of cameras.
	 */
	function onClose():Void
	{
		removeEventListener(Event.DEACTIVATE, onFocusLost);
		removeEventListener(Event.ACTIVATE, onFocus);
		removeEventListener(Event.RESIZE, onResize);
		stage.removeChild(_inputContainer);
		FlxG.windows.remove(this);
	}

	function onFocus(_):Void
	{
		trace('focus on win');
	}

	function onFocusLost(_):Void
	{
		trace('focus lost on win');
	}

	function onResize(_):Void
	{
		// TODO this does not work correctly because cameras.resize() refers to FlxG attrs.
		trace('resizing window');
		_width = stage.stageWidth;
		_height = stage.stageHeight;

		cameras.resize();
	}
}
