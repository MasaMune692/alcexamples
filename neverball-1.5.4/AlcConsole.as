package com.adobe.alchemy
{
  import flash.display.Sprite;
  import flash.text.TextField;
  import flash.display.StageScaleMode;
  import flash.display.DisplayObjectContainer;
  import flash.display.Bitmap
  import flash.display.BitmapData
  import flash.net.URLRequest;
  import flash.net.URLLoader;
  import flash.net.URLLoaderDataFormat;
  import flash.events.EventDispatcher;
  import flash.events.ProgressEvent;
  import flash.events.SecurityErrorEvent;
  import flash.events.IOErrorEvent;
  import flash.events.AsyncErrorEvent;
  import flash.geom.Rectangle
  import flash.utils.ByteArray
  import flash.net.LocalConnection;
  import flash.net.URLRequest;
  import flash.events.Event;
  import flash.events.KeyboardEvent;
  import flash.events.MouseEvent;
  import flash.media.SoundChannel;
  import flash.media.Sound;
  import flash.events.SampleDataEvent;
  import C_Run.ram;
  import C_Run.initLib;
  import com.adobe.alchemyvfs.InMemoryBackingStore;
  import Stage3DGL.GLAPI;
  import flash.display.Stage3D;
  import flash.display3D.Context3D;
  import flash.display3D.Context3DRenderMode;
  import flash.display.StageAlign;
  import flash.utils.getTimer;
  //import deng.fzip.*;
  import nochump.util.zip.*

    /*class FZipBackingStore extends InMemoryBackingStore {
      public function FZipBackingStore(datazip:FZip) {
        var dirs:Object = {}
        var n:int = datazip.getFileCount();
         addDirectory("/");
        for(var i:int=0; i<n; i++) {
          var fzf:FZipFile = datazip.getFileAt(i);
          trace(fzf.filename)
          var idx:int = fzf.filename.lastIndexOf("/");
          if(idx == fzf.filename.length-1){
            trace("dir: " + fzf.filename)
              addDirectory("/"+fzf.filename);
          } else {
            trace("file: " + fzf.filename)
            addFile("/"+fzf.filename, fzf.content);
          }
        }
      }
    }
    */

    class ZipBackingStore extends InMemoryBackingStore {
      public function ZipBackingStore()
      {
      }

      public function addZip(data:ByteArray) {
        var zip = new ZipFile(data)
        for (var i = 0; i < zip.entries.length; i++) {
          var e = zip.entries[i]
          if (e.isDirectory()) {
            addDirectory("/"+e.name)
          } else {
            addFile("/"+e.name, zip.getInput(e))
            trace(e.name)
          }
        }
      }
    }

  public class AlcConsole extends Sprite
  {
    public static var current:AlcConsole;
    private var enableConsole:Boolean = false;
    private static var _width:int = 1024;
    private static var _height:int = 768;
    private var bm:Bitmap
    private var bmd:BitmapData
    private var vbufferptr:int, vgl_mx:int, vgl_my:int, kp:int, vgl_buttons:int;
    //private var enginetickptr:int
    private var mainloopTickPtr:int, soundUpdatePtr:int, audioBufferPtr:int;
    private var _tf:TextField;
    private var inputContainer
    private var keybytes:ByteArray = new ByteArray()
    private var mx:int = 0, my:int = 0, last_mx:int = 0, last_my:int = 0, button:int = 0;
    private var snd:Sound = null
    private var sndChan:SoundChannel = null
    public var sndDataBuffer:ByteArray = null
    private var _stage:Stage3D;
    private var _context:Context3D;
    private var rendered:Boolean = false;
    private var datazips:Array = [];
    private var zfs:ZipBackingStore

    public function AlcConsole(container:DisplayObjectContainer = null)
    {
      AlcConsole.current = this;
      stage.frameRate = 60;

      zfs = new ZipBackingStore()
      CModule.getVFS().addBackingStore(zfs, null);

      var datazip1 = new URLLoader(new URLRequest("data1.zip"));
      datazip1.dataFormat = URLLoaderDataFormat.BINARY;
      datazip1.addEventListener(AsyncErrorEvent.ASYNC_ERROR, onError)
      datazip1.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onError)
      datazip1.addEventListener(IOErrorEvent.IO_ERROR, onError)
      datazip1.addEventListener(Event.COMPLETE, onComplete)
      datazip1.addEventListener(ProgressEvent.PROGRESS, onProgress)

      var datazip2 = new URLLoader(new URLRequest("data2.zip"));
      datazip2.dataFormat = URLLoaderDataFormat.BINARY;
      datazip2.addEventListener(AsyncErrorEvent.ASYNC_ERROR, onError)
      datazip2.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onError)
      datazip2.addEventListener(IOErrorEvent.IO_ERROR, onError)
      datazip2.addEventListener(Event.COMPLETE, onComplete)
      datazip2.addEventListener(ProgressEvent.PROGRESS, onProgress)

      var datazip3 = new URLLoader(new URLRequest("data3.zip"));
      datazip3.dataFormat = URLLoaderDataFormat.BINARY;
      datazip3.addEventListener(AsyncErrorEvent.ASYNC_ERROR, onError)
      datazip3.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onError)
      datazip3.addEventListener(IOErrorEvent.IO_ERROR, onError)
      datazip3.addEventListener(Event.COMPLETE, onComplete)
      datazip3.addEventListener(ProgressEvent.PROGRESS, onProgress)
    }

    private function onComplete(e:Event):void
    {
      datazips.push(e.target.data);
      if(datazips.length == 3)
        initG(null)

      //CModule.getVFS().addBackingStore(vfs, null)

      //CModule.getVFS().addBackingStore(new RootFSBackingStore(datazip.data), null)
      //initG(null)
    }

    private function onError(e:Event):void
    {
    }

    private function onProgress(e:Event):void
    {
    }

    private function initG(e:Event):void
    {
      inputContainer = new Sprite()
      addChild(inputContainer)

      stage.align = StageAlign.TOP_LEFT;
      stage.scaleMode = StageScaleMode.NO_SCALE;
      stage.addEventListener(KeyboardEvent.KEY_DOWN, bufferKeyDown);
      stage.addEventListener(KeyboardEvent.KEY_UP, bufferKeyUp);
      stage.addEventListener(MouseEvent.MOUSE_MOVE, bufferMouseMove);
      stage.addEventListener(MouseEvent.MOUSE_DOWN, bufferMouseDown);
      stage.addEventListener(MouseEvent.MOUSE_UP, bufferMouseUp);
      stage.frameRate = 60;
      stage.scaleMode = StageScaleMode.NO_SCALE;

      if(enableConsole) {
      _tf = new TextField;
      _tf.multiline = true;
      _tf.width = _width;
      _tf.height = _height;
      inputContainer.addChild(_tf);
      }
    
    _stage = stage.stage3Ds[0];
    _stage.addEventListener(Event.CONTEXT3D_CREATE, context_created);
    //_stage.requestContext3D(Context3DRenderMode.AUTO);
    _stage.requestContext3D("auto");
  }

  private function context_created(e:Event):void
  {
      _context = _stage.context3D;
      _context.configureBackBuffer(_width, _height, 4, true /*enableDepthAndStencil*/ );
      _context.enableErrorChecking = false;
      
      trace(_context.driverInfo);
      GLAPI.init(_context, null, stage);
          var gl:GLAPI = GLAPI.instance;
          gl.context.clear(0.0, 0.0, 0.0);
          gl.context.present();
          this.addEventListener(Event.ENTER_FRAME, runMain);
          stage.addEventListener(Event.RESIZE, stageResize);
    }
    
    private function stageResize(event:Event):void
    {
        // need to reconfigure back buffer
        _width = stage.stageWidth;
        _height = stage.stageHeight;
        _context.configureBackBuffer(_width, _height, 4, true /*enableDepthAndStencil*/ );
    }


    private function runMain(event:Event):void
    {
      // Keep Loading VFS zips until we're done
      if(datazips.length > 0) {
        zfs.addZip(datazips.pop());
        return;
      }

      this.removeEventListener(Event.ENTER_FRAME, runMain);

    var argv:Vector.<String> = new Vector.<String>();
    argv.push("/data/neverball.swf");
      initLib(this, argv);
      vbufferptr = CModule.read32(CModule.getPublicSym("__avm2_vgl_argb_buffer"))
      vgl_mx = CModule.getPublicSym("vgl_cur_mx");
      vgl_my = CModule.getPublicSym("vgl_cur_my");
      vgl_buttons = CModule.getPublicSym("vgl_cur_buttons");

    mainloopTickPtr = CModule.getPublicSym("mainLoopTick");
      soundUpdatePtr = CModule.getPublicSym("audio_step");
      audioBufferPtr = CModule.getPublicSym("audioBuffer");
      addEventListener(Event.ENTER_FRAME, framebufferBlit);
    }

    public function write(fd:int, buf:int, nbyte:int, errno_ptr:int):int
    {
      var str:String = CModule.readString(buf, nbyte);
      i_write(str);
      return nbyte;
    }

    public function read(fd:int, buf:int, nbyte:int, errno_ptr:int):int
    {
      if(fd == 0 && nbyte == 1) {
        keybytes.position = kp++;
        if(keybytes.bytesAvailable) {
          CModule.write8(buf, keybytes.readUnsignedByte());
        } else {
        keybytes.position = 0;
        kp = 0;
        }
      }
      return 0;
    }

    public function bufferMouseMove(me:MouseEvent) 
    {
      me.stopPropagation();
      mx = me.stageX;
      my = me.stageY;
    }
    
    public function bufferMouseDown(me:MouseEvent) 
    {
      me.stopPropagation();
      mx = me.stageX;
      my = me.stageY;
      button = 1;
    }
    
    public function bufferMouseUp(me:MouseEvent) 
    {
      me.stopPropagation();
      mx = me.stageX;
      my = me.stageY;
      button = 0;
    }


    public function bufferKeyDown(ke:KeyboardEvent) 
    {
      ke.stopPropagation();

      keybytes.writeByte(int(ke.keyCode & 0x7F));
    }
    
    public function bufferKeyUp(ke:KeyboardEvent) 
    {
      ke.stopPropagation();

      keybytes.writeByte(int(ke.keyCode | 0x80));
    }

    public function consoleWrite(s:String):void
    {
      if(enableConsole) {
        _tf.appendText(s);
        _tf.scrollV = _tf.maxScrollV
      }
      trace(s);
    }

    public function i_exit(code:int):void
    {
      consoleWrite("\nexit code: " + code + "\n");
    }

    public function i_error(e:String):void
    {
       consoleWrite("\nexception: " + e + "\n");
    }

    public function i_write(str:String):void
    {
      consoleWrite(str);
    }

    public function sndComplete(e:Event):void
    {
      sndChan.removeEventListener(Event.SOUND_COMPLETE, sndComplete);
      sndChan = snd.play();
      sndChan.addEventListener(Event.SOUND_COMPLETE, sndComplete);
    }

    public function sndData(e:SampleDataEvent):void
    {
      CModule.callFun(soundUpdatePtr, new Vector.<int>)
      e.data.endian = "littleEndian"
      e.data.length = 0
      var ap:int = CModule.read32(audioBufferPtr)
      //e.data.writeBytes(ram, ap, 16384);
      
      for(var i:int=0; i<16384; i+=2) {
        ram.position = ap+i;
        var s:int = ram.readShort()
        var v:Number = (s / 32768.0)
        e.data.writeFloat(v)
      }
    }

    public function framebufferBlit(e:Event):void
    {
      CModule.write32(vgl_mx, mx);
      CModule.write32(vgl_my, my);
      CModule.write32(vgl_buttons, button);

      var gl:GLAPI = GLAPI.instance;
      CModule.callFun(mainloopTickPtr, new Vector.<int>());
      gl.context.present();

      if(!snd)
      {
        snd = new Sound();
        snd.addEventListener( SampleDataEvent.SAMPLE_DATA, sndData );
      }
      if (!sndChan)
      {
        sndChan = snd.play();
        sndChan.addEventListener(Event.SOUND_COMPLETE, sndComplete);
      }
    }
  }
}
