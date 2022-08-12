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

	IMPORTANT - 7 (RVW), 6, 8 (RSLVD), 18 (RSLVD)

	9. When a non-main window is closed should all its cameras be removed from all sprites in the game ?
	10. onClose() does not cleanup any FlxSprite which has cameras from the window in their list of cameras.
		a. what happens if a camera goes away that is referenced by a sprite. I bet it doesn't go away because of the reference - but it cannot draw anywhere - does that cause issues ?
	15. cursor should be visible in all windows - or at least be able to be - not all at once but whichever window the mouse is over

	20. Remove all @:access metadata and if necessary replace within flixel with @:allow. If not possible we have a problem.
	21. How to test and what tests to add.
	22. How can a secondary window receive focus and process input ? When it gets focus the main window is paused.
			probably need to set FlxG.autoPause = false explicitly for this to work. Add to demo.
	23. _camera should be like the camera in FlxGame, so probably public
	24. When you access the lime.ui.window in FlxG you go FlxG.game.stage.window. In FlxWindow it should be the same.

	Resolved
	6. resize on FlxWindows doesn't work - camera doesn't resize
		Camera resize is tied to game main window resize via FlxG globals including the game size. This needs to be fixed before window resize will be easy to implement. It is possible to hack it but that gets really ugly. Hopefully window resize is not required for secondary windows initially.

	7. putting cameras from two windows on a sprite results in it rendering to the second one only
		The problem is that the texture is rendered using a shader via FlxDrawQuadsItem.render. The shader has a Context3D object which is specific to the window. So this needs to change for any sprite rendering to multiple windows, as the render switches from window to window. This requires access to the __context field of the openfl.display.Shader class. This a hack. The right way is probably to create a completely separate shader for each window rendering the sprite.

		This turns out to be a serious issue. The problem is that the shader is coming from the FlxSprite.graphic.shader which is only initialized with a Context3D object when first rendered. There is a TODO in the OpenGLRenderer about switching GL contexts but it remains unimplemented. It is therefore possible the hack is not that far off. Seek input in PR.

	8. focus is lost on the first window when clicking on others. Bringing all windows to front is not easy without causing loops in the focus() behaviour. When any window is brought into focus, all should be brought to front and the main window be given focus - this may change if a window should have focus, but will do for now.

		Lime cannot do this. SDL has a raise window function - SDL_RaiseWindow - but it gives focus to the window too. Apparently there was a request to add a flag to this function but as of 2016 it was not implemeneted.

		For now, this will be a manual exercise for the user. This means the user basically has to restart the game actually.

	19. Do default cameras need to be modified so that a default camera could be in any window ? Or should all FlxWindow cameras be non-default ? The latter is probably easier but might not be what people expect

		All window cameras are non-default
		
	18. should FlxG.scaleMode.scale be per window ? My guess is all windows should scale the same way.
		See if any reviewer says anything but this sounds ok.

		See 25 below - due to the way things are wired up right now this is just plain hard to get to work properly. I think FlxG.scaleMode should be made to be per-window but that's additional work.

	25. there is some problem with camera walls but I am not if it is due to the window mod.
		ok so this is unexpected - when you create a camera wall it creates 4 tileblocks around the camera - fine. These are sprites and they are therefore on the default camera, but they are transparent. But if the window of the default camera is not big enough that the tiles can be visible they they get truncated or not displayed somehow. I don't know how yet. But my main window was narrow - 400 px. The walls were created about cameras in other wider windows. This resulted in just the left and part of the top and bottom of the walls rendering. This led to my blocks that I was bouncing around the windows being able to escape on the right sides or the top and bottom beyond 400px. Now I have to figure out how to fix it but that's the basic issue.

		This is due to the camera being bigger than the main camera window - the flxgame default one. That means it extends beyond world bounds. So to fix this you need to increase the world bounds to at least the range of the largest camera in the system.

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
		g. test closing window for impact of destroy(), particularly camera.destroy if there are still sprites on it.
		h. test whether input can be accepted in secondary window
 */
class FlxWindow extends Sprite
{
	public var windowWidth(default, null):Int;
	public var windowHeight(default, null):Int;
	public var windowName(default, null):String;

	var _initialX:Int;
	var _initialY:Int;

	@:allow(flixel.system.frontEnds.CameraFrontEnd)
	var _inputContainer:Sprite;

	// @:allow(flixel.FlxWindowManager)
	public var window:lime.ui.Window;

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
			resizable: false,
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
		window = FlxG.stage.application.createWindow(attributes);

		window.x = _initialX;
		window.y = _initialY;

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
		cameras.add(_camera, false);

		addEventListener(Event.DEACTIVATE, onFocusLost);
		addEventListener(Event.ACTIVATE, onFocus);

		// stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
		// We need to listen for resize event which means new context
		// it means that we need to recreate BitmapDatas of dumped tilesheets
		stage.window.onClose.add(onClose, false, 0);

		stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
	}

	function onEnterFrame(_):Void
	{
		FlxG.renderingWindow = this;
		FlxG.game.draw();
		FlxG.renderingWindow = null;
	}

	public function addCamera(camera:FlxCamera):Void
	{
		cameras.add(camera, false);
	}

	/**
	 * Remove the window from the window manager when it is closed.
	 * TODO - this does not cleanup any FlxSprite which have cameras from the window in their list of cameras.
	 */
	function onClose():Void
	{
		removeEventListener(Event.DEACTIVATE, onFocusLost);
		removeEventListener(Event.ACTIVATE, onFocus);
		stage.removeChild(_inputContainer);
		FlxG.windows.remove(this);
	}

	function onFocus(_):Void
	{
		trace('focus on win ${windowName}');
	}

	function onFocusLost(_):Void
	{
		trace('focus lost on win ${windowName}');
	}

	public function destroy():Void
	{
		// FIXME Is this safe ?
		// while (cameras.list.length > 0)
		// {
		// 	var c = cameras.list.pop();
		// 	c.destroy();
		// }

		// FIXME Need to figure out removal order for sprites
		// removeChild(_inputContainer);
	}
}
