package flixel;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.graphics.tile.FlxDrawBaseItem;
import flixel.system.frontEnds.CameraFrontEnd;
import flixel.util.FlxColor;
import openfl.display.DisplayObjectRenderer;
import openfl.display.OpenGLRenderer;
import openfl.display.Sprite;
import openfl.display.StageAlign;
import openfl.display.StageScaleMode;
import openfl.events.Event;

// import flixel.system.frontEnds.CameraFrontEndWin;
/*
	TODO

	IMPORTANT - 7, 6, 8 and 14, 13, 16, 18
	6. resize on FlxWindows doesn't work - camera doesn't resize
	7. putting cameras from two windows on a sprite results in it rendering to the second one only
		The problem is that the texture is rendered using a shader via FlxDrawQuadsItem.render. The shader has a Context3D object which is specific to the window. So this needs to change for any sprite rendering to multiple windows, as the render switches from window to window. This requires access to the __context field of the openfl.display.Shader class. This a hack. The right way is probably to create a completely separate shader for each window rendering the sprite.
	8. focus is lost on the first window when clicking on others. Bringing all windows to front is not easy without causing loops in the focus() behaviour
	9. When a non-main window is closed should all its cameras be removed from all sprites in the game ?
	10. onClose() does not cleanup any FlxSprite which has cameras from the window in their list of cameras.
		a. what happens if a camera goes away that is referenced by a sprite. I bet it doesn't go away because of the reference - but it cannot draw anywhere - does that cause issues ?
	13. If you create windows in the initial PlayState.create() then the main camera bgcolor cannot be changed
		a. I suspect that the bgcolor of the main camera is being set later but even trying to change it later with FlxG.camera fails suggesting that that camera is no longer the main window camera
	14. when any window is brought into focus, all should be brought to front and the main window be given focus - this may change if a window should have focus, but will do for now.
	15. cursor should be visible in all windows - or at least be able to be - not all at once but whichever window the mouse is over
	16. Figure out how to get rid of CameraFrontEndWin.hx and just modify the regular CameraFrontEnd
	17. If the camera.bgcolor in different windows does not match then a sprite drawn to both windows may be invisible even with the context3d switching hack. Basically I think a new shader has to be created.
	18. should FlxG.scaleMode.scale be per window ? My guess is all windows should scale the same way.
	19. Do default cameras need to be modified so that a default camera could be in any window ? Or should all FlxWindow cameras be non-default ? The latter is probably easier but might not be what people expect

	Notes

	1. fullscreen is a bit meaningless but harmless. If anyone can figure out what it should do for MW then that can be implemented. As only the main game window has a maximise button it covers all the others but it can be shrunk again and the other windows continue ok. Perhaps advise MW devs that they should prevent fullscreen, or in fact resize by the user
	2. Currently FlxG.cameras.bgColor = FOO will set all cameras on the list to that bgColor. As each window has separate lists this won't work there - so people would have to iterate over all windows doing this if they wanted all windows cameras to have the one bgColor. What is the best option here ?
	3. Cameras used game size and width as default regardless of the window they are going to be. I think this is ok as, you have no way to get any other window size that makes any sense at camera creation time, and anyone specifically targetting a different window will likely set the size.

	Testing
		a. sprite draws to multiple windows
		b. sprites draws to multiple windows with different bg colors
		c. bring one window front brings all
		d. closing main window closes all windows
		e. main game window is the one with focus - do I need this test ? I need the feature
		f. test window resize and make sure cameras also resize correctly
 */
class FlxWindow extends Sprite
{
	public var _win:lime.ui.Window;

	@:allow(flixel.system.frontEnds.CameraFrontEnd)
	var _inputContainer:Sprite;

	public var windowWidth(default, null):Int;
	public var windowHeight(default, null):Int;

	var _initialX:Int;
	var _initialY:Int;

	public var windowName(default, null):String;

	/**
	 * Contains things related to cameras, a list of all cameras and several effects like `flash()` or `fade()`.
	 */
	public var cameras(default, null):CameraFrontEnd;

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
		windowWidth = width;
		windowHeight = height;
		_initialX = x;
		_initialY = y;
		windowName = name;

		_inputContainer = new Sprite();

		var attributes:lime.ui.WindowAttributes = {
			allowHighDPI: false,
			alwaysOnTop: false,
			borderless: true,
			// display: 0,
			element: null,
			frameRate: FlxG.updateFramerate,
			#if !web
			fullscreen: false,
			#end
			height: windowHeight,
			hidden: #if munit true #else false #end,
			maximized: false,
			minimized: false,
			parameters: {},
			resizable: true,
			title: windowName,
			width: windowWidth,
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

		// Setup the front end and default camera
		// var cfew = new CameraFrontEndWin(this);
		var cfew = new CameraFrontEnd(this);
		cfew.bgColor = FlxColor.TRANSPARENT;
		cameras = cfew;

		_camera = new FlxCamera(0, 0, windowWidth, windowHeight);
		cameras.add(_camera);

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
		windowWidth = stage.stageWidth;
		windowHeight = stage.stageHeight;

		cameras.resize();
	}
}
