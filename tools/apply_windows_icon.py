"""Apply/verify ICO resources using Windows APIs; no external resource editor.

Run after a Windows export. Existing PCK data must remain in the adjacent .pck.
Only icon resources change. Stage and verify each EXE before replacing it.
"""
import argparse
import ctypes as c
from ctypes import wintypes as w
from contextlib import contextmanager
import os
from pathlib import Path
import shutil
import struct

project=Path(__file__).resolve().parents[1]
kernel=c.WinDLL('kernel32',use_last_error=True)
NAME_CALLBACK=c.WINFUNCTYPE(w.BOOL,w.HMODULE,c.c_void_p,c.c_void_p,c.c_ssize_t)
LANG_CALLBACK=c.WINFUNCTYPE(w.BOOL,w.HMODULE,c.c_void_p,c.c_void_p,w.WORD,c.c_ssize_t)
kernel.LoadLibraryExW.argtypes=[w.LPCWSTR,w.HANDLE,w.DWORD];kernel.LoadLibraryExW.restype=w.HMODULE
kernel.FreeLibrary.argtypes=[w.HMODULE];kernel.FreeLibrary.restype=w.BOOL
kernel.EnumResourceNamesW.argtypes=[w.HMODULE,c.c_void_p,NAME_CALLBACK,c.c_ssize_t];kernel.EnumResourceNamesW.restype=w.BOOL
kernel.EnumResourceLanguagesW.argtypes=[w.HMODULE,c.c_void_p,c.c_void_p,LANG_CALLBACK,c.c_ssize_t];kernel.EnumResourceLanguagesW.restype=w.BOOL
kernel.FindResourceExW.argtypes=[w.HMODULE,c.c_void_p,c.c_void_p,w.WORD];kernel.FindResourceExW.restype=c.c_void_p
kernel.SizeofResource.argtypes=[w.HMODULE,c.c_void_p];kernel.SizeofResource.restype=w.DWORD
kernel.LoadResource.argtypes=[w.HMODULE,c.c_void_p];kernel.LoadResource.restype=c.c_void_p
kernel.LockResource.argtypes=[c.c_void_p];kernel.LockResource.restype=c.c_void_p
kernel.BeginUpdateResourceW.argtypes=[w.LPCWSTR,w.BOOL];kernel.BeginUpdateResourceW.restype=w.HANDLE
kernel.UpdateResourceW.argtypes=[w.HANDLE,c.c_void_p,c.c_void_p,w.WORD,c.c_void_p,w.DWORD];kernel.UpdateResourceW.restype=w.BOOL
kernel.EndUpdateResourceW.argtypes=[w.HANDLE,w.BOOL];kernel.EndUpdateResourceW.restype=w.BOOL

@contextmanager
def pointer(name):
    if isinstance(name,int): yield c.c_void_p(name)
    else:
        buffer=c.create_unicode_buffer(name)
        yield c.cast(buffer,c.c_void_p)

@contextmanager
def module(path):
    handle=kernel.LoadLibraryExW(str(path),None,0x22)
    if not handle: raise c.WinError(c.get_last_error())
    try: yield handle
    finally: kernel.FreeLibrary(handle)

def names(handle,kind):
    result=[]
    @NAME_CALLBACK
    def callback(_module,_kind,name,_param):
        result.append(name if name<=65535 else c.wstring_at(name))
        return True
    c.set_last_error(0)
    if not kernel.EnumResourceNamesW(handle,c.c_void_p(kind),callback,0):
        error=c.get_last_error()
        if error not in [0,1812,1813,1814]: raise c.WinError(error)
    return result

def languages(handle,kind,name):
    result=[]
    @LANG_CALLBACK
    def callback(_module,_kind,_name,language,_param):
        result.append(language);return True
    with pointer(name) as address:
        if not kernel.EnumResourceLanguagesW(handle,c.c_void_p(kind),address,callback,0): raise c.WinError(c.get_last_error())
    return result

def resource(handle,kind,name,language):
    with pointer(name) as address: found=kernel.FindResourceExW(handle,c.c_void_p(kind),address,language)
    if not found: raise c.WinError(c.get_last_error())
    length=kernel.SizeofResource(handle,found)
    loaded=kernel.LoadResource(handle,found)
    return c.string_at(kernel.LockResource(loaded),length)

def frames(path):
    raw=path.read_bytes()
    reserved,kind,count=struct.unpack_from('<HHH',raw)
    assert reserved==0 and kind==1 and count>0,'Invalid ICO header'
    result=[]
    for i in range(count):
        width,height,colors,pad,planes,bits,length,offset=struct.unpack_from('<BBBBHHII',raw,6+i*16)
        data=raw[offset:offset+length]
        assert len(data)==length and data.startswith(b'\x89PNG'),'Expected PNG-compressed ICO frame'
        result.append((width,height,colors,planes or 1,bits or 32,data))
    return result

def update(handle,kind,name,language,data):
    buffer=c.create_string_buffer(data) if data is not None else None
    with pointer(name) as address:
        if not kernel.UpdateResourceW(handle,c.c_void_p(kind),address,language,buffer,len(data) if data is not None else 0): raise c.WinError(c.get_last_error())

def verify(path,images):
    groups=0
    sizes=set()
    with module(path) as handle:
        for name in names(handle,14):
            for language in languages(handle,14,name):
                group=resource(handle,14,name,language)
                assert struct.unpack_from('<HHH',group)==(0,1,len(images))
                for i,image in enumerate(images):
                    width,height,colors,pad,planes,bits,length,image_id=struct.unpack_from('<BBBBHHIH',group,6+i*14)
                    assert (width,height,colors,planes,bits,length)==(*image[:5],len(image[5]))
                    assert resource(handle,3,image_id,language)==image[5], 'EXE icon does not match current artwork'
                    sizes.add(width or 256)
                groups+=1
    assert groups>0 and {16,32,48,64,128,256}.issubset(sizes)
    print(path.name,': verified',groups,'icon group/languages, sizes',sorted(sizes))

def apply(path,images):
    with path.open('rb') as binary:
        binary.seek(-4,2)
        assert binary.read(4)!=b'GDPC','Use an external PCK before changing EXE resources.'
    stage=path.with_name(path.stem+'.icon-stage.exe')
    shutil.copy2(path,stage)
    with module(stage) as handle:
        old=[(kind,name,language) for kind in [3,14] for name in names(handle,kind) for language in languages(handle,kind,name)]
    groups={(name,language) for kind,name,language in old if kind==14} or {(1,0)}
    groups|={(name,0) for name,_language in groups}
    all_languages={language for _name,language in groups}
    group=struct.pack('<HHH',0,1,len(images))
    for i,(width,height,colors,planes,bits,data) in enumerate(images):
        group+=struct.pack('<BBBBHHIH',width,height,colors,0,planes,bits,len(data),1000+i)
    update_handle=kernel.BeginUpdateResourceW(str(stage),False)
    if not update_handle: raise c.WinError(c.get_last_error())
    try:
        for kind,name,language in old: update(update_handle,kind,name,language,None)
        for language in all_languages:
            for i,image in enumerate(images): update(update_handle,3,1000+i,language,image[5])
        for name,language in groups: update(update_handle,14,name,language,group)
    except BaseException:
        kernel.EndUpdateResourceW(update_handle,True);raise
    if not kernel.EndUpdateResourceW(update_handle,False): raise c.WinError(c.get_last_error())
    verify(stage,images)
    os.replace(stage,path)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify-only',action='store_true')
    args=parser.parse_args()
    images=frames(project/'assets/charm-city-beatdown.ico')
    for name in ['CharmCityBeatdown.exe','CharmCityBeatdown_console.exe']:
        path=project/'build'/name
        if not path.exists(): continue
        if not args.verify_only: apply(path,images)
        verify(path,images)
    if not args.verify_only:
        shell=c.WinDLL('shell32')
        shell.SHChangeNotify(0x08000000,0,None,None)
if __name__=='__main__':main()
