"""Check the icons Windows supplies for the EXE, shortcut and running game."""
import argparse
import ctypes as c
from ctypes import wintypes as w
from pathlib import Path
import subprocess
import time
from PIL import Image

project=Path(__file__).resolve().parents[1]
user=c.WinDLL('user32',use_last_error=True)
gdi=c.WinDLL('gdi32',use_last_error=True)
shell=c.WinDLL('shell32',use_last_error=True)
class IconInfo(c.Structure):
    _fields_=[('fIcon',w.BOOL),('xHotspot',w.DWORD),('yHotspot',w.DWORD),('hbmMask',w.HBITMAP),('hbmColor',w.HBITMAP)]
class Bitmap(c.Structure):
    _fields_=[('bmType',w.LONG),('bmWidth',w.LONG),('bmHeight',w.LONG),('bmWidthBytes',w.LONG),('bmPlanes',w.WORD),('bmBitsPixel',w.WORD),('bmBits',c.c_void_p)]
class BitmapInfo(c.Structure):
    _fields_=[('biSize',w.DWORD),('biWidth',w.LONG),('biHeight',w.LONG),('biPlanes',w.WORD),('biBitCount',w.WORD),('biCompression',w.DWORD),('biSizeImage',w.DWORD),('biXPelsPerMeter',w.LONG),('biYPelsPerMeter',w.LONG),('biClrUsed',w.DWORD),('biClrImportant',w.DWORD)]
class ShellFileInfo(c.Structure):
    _fields_=[('hIcon',w.HICON),('iIcon',c.c_int),('dwAttributes',w.DWORD),('szDisplayName',w.WCHAR*260),('szTypeName',w.WCHAR*80)]
CALLBACK=c.WINFUNCTYPE(w.BOOL,w.HWND,w.LPARAM)
user.LoadImageW.argtypes=[w.HINSTANCE,w.LPCWSTR,w.UINT,c.c_int,c.c_int,w.UINT];user.LoadImageW.restype=w.HICON
user.GetIconInfo.argtypes=[w.HICON,c.POINTER(IconInfo)];user.GetIconInfo.restype=w.BOOL
user.DrawIconEx.argtypes=[w.HDC,c.c_int,c.c_int,w.HICON,c.c_int,c.c_int,w.UINT,w.HBRUSH,w.UINT];user.DrawIconEx.restype=w.BOOL
user.DestroyIcon.argtypes=[w.HICON]
user.EnumWindows.argtypes=[CALLBACK,w.LPARAM]
user.GetWindowThreadProcessId.argtypes=[w.HWND,c.POINTER(w.DWORD)]
user.SendMessageW.argtypes=[w.HWND,w.UINT,w.WPARAM,w.LPARAM];user.SendMessageW.restype=c.c_void_p
gdi.CreateCompatibleDC.argtypes=[w.HDC];gdi.CreateCompatibleDC.restype=w.HDC
gdi.CreateDIBSection.argtypes=[w.HDC,c.POINTER(BitmapInfo),w.UINT,c.POINTER(c.c_void_p),w.HANDLE,w.DWORD];gdi.CreateDIBSection.restype=w.HBITMAP
gdi.SelectObject.argtypes=[w.HDC,w.HGDIOBJ];gdi.SelectObject.restype=w.HGDIOBJ
gdi.DeleteObject.argtypes=[w.HGDIOBJ];gdi.DeleteDC.argtypes=[w.HDC]
gdi.GetObjectW.argtypes=[w.HGDIOBJ,c.c_int,c.c_void_p]
shell.SHGetFileInfoW.argtypes=[w.LPCWSTR,w.DWORD,c.POINTER(ShellFileInfo),w.UINT,w.UINT];shell.SHGetFileInfoW.restype=c.c_size_t

def dimensions(icon):
    info=IconInfo()
    assert user.GetIconInfo(icon,c.byref(info))
    try:
        bitmap=Bitmap();assert gdi.GetObjectW(info.hbmColor,c.sizeof(bitmap),c.byref(bitmap))
        return bitmap.bmWidth,bitmap.bmHeight
    finally:
        gdi.DeleteObject(info.hbmMask);gdi.DeleteObject(info.hbmColor)

def pixels(icon,size):
    info=BitmapInfo(c.sizeof(BitmapInfo),size,-size,1,32,0,size*size*4,0,0,0,0)
    dc=gdi.CreateCompatibleDC(None);address=c.c_void_p()
    bitmap=gdi.CreateDIBSection(dc,c.byref(info),0,c.byref(address),None,0)
    assert bitmap and address.value
    old=gdi.SelectObject(dc,bitmap)
    try:
        c.memset(address,0,size*size*4)
        assert user.DrawIconEx(dc,0,0,icon,size,size,0,None,3)
        return c.string_at(address,size*size*4)
    finally:
        gdi.SelectObject(dc,old);gdi.DeleteObject(bitmap);gdi.DeleteDC(dc)

def expected(size):
    icon=user.LoadImageW(None,str(project/'assets/charm-city-beatdown.ico'),1,size,size,0x10)
    assert icon
    try:return pixels(icon,size)
    finally:user.DestroyIcon(icon)

def check_icon(icon,label,output):
    size=dimensions(icon)[0]
    actual=pixels(icon,size);reference=expected(size)
    indices=range(len(actual))
    if label=='desktop-shortcut':
        # The standard Windows shortcut arrow overlays the lower-left quadrant.
        indices=[i for i in indices if (i//4)%size>=size//2 or (i//4)//size<size//2]
    error=sum(abs(actual[i]-reference[i]) for i in indices)/(len(indices)*255)
    # Windows may rescale a different source size.
    Image.frombytes('RGBA',(size,size),actual,'raw','BGRA').save(output/(label+'.png'))
    assert error<.065,(label,size,error)
    print('PASS',label,size,'px; normalized difference',round(error,5))

def shell_icon(path):
    info=ShellFileInfo()
    assert shell.SHGetFileInfoW(str(path),0,c.byref(info),c.sizeof(info),0x100)
    return info.hIcon

def window_for(pid):
    result=[]
    @CALLBACK
    def callback(window,_param):
        owner=w.DWORD();user.GetWindowThreadProcessId(window,c.byref(owner))
        if owner.value==pid:result.append(window)
        return True
    user.EnumWindows(callback,0)
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--shortcut',type=Path)
    parser.add_argument('--output',type=Path,default=project.parent/'work/icon-check')
    args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    exe=project/'build/CharmCityBeatdown.exe'
    for label,path in [('explorer-exe',exe),('desktop-shortcut',args.shortcut)]:
        if not path:continue
        icon=shell_icon(path)
        try:check_icon(icon,label,args.output)
        finally:user.DestroyIcon(icon)
    startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
    process=subprocess.Popen([str(exe),'--position','-10000,-10000','--quit-after','240','--log-file',str(args.output/'game.log')],startupinfo=startup)
    found=False
    try:
        deadline=time.monotonic()+20
        while time.monotonic()<deadline and process.poll() is None:
            for window in window_for(process.pid):
                big=user.SendMessageW(window,0x7f,1,0)
                small=user.SendMessageW(window,0x7f,0,0)
                if big and small:
                    check_icon(big,'running-window-large',args.output)
                    check_icon(small,'running-window-small',args.output)
                    found=True;break
            if found:break
            time.sleep(.05)
        assert found,'The running game did not expose its native Windows icons.'
        assert process.wait(timeout=20)==0
    finally:
        if process.poll() is None:process.terminate();process.wait(timeout=5)
    print('PASS Windows file, shortcut, titlebar and taskbar icon integration')
if __name__=='__main__':main()
