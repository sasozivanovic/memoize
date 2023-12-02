#!/bin/env python

from memoize_extract import *
import memoize_extract
import shutil, stat, pathlib, platform

class Test:
    batch = 0
    n = 0
    def __init__(self, texmf_output_directory, texmfoutput, openin_any = 'a', openout_any = 'p'):
        self.texmf_output_directory = Path(texmf_output_directory) if texmf_output_directory else None
        self.texmfoutput = Path(texmfoutput) if texmfoutput else None
        self.openin_any = openin_any
        self.openout_any = openout_any
    def __enter__(self):
        global texmf_output_directory
        global texmfoutput
        global openin_any
        global openout_any
        self.original_texmf_output_directory = texmf_output_directory
        self.original_texmfoutput = texmfoutput
        self.original_openin_any = openin_any
        self.original_openout_any = openout_any
        texmf_output_directory = self.texmf_output_directory
        texmfoutput = self.texmfoutput
        openin_any = self.openin_any
        openout_any = self.openout_any
        memoize_extract.texmf_output_directory = self.texmf_output_directory
        memoize_extract.texmfoutput = self.texmfoutput
        memoize_extract.openin_any = self.openin_any
        memoize_extract.openout_any = self.openout_any
        ####################################################################
        ###### THIS DELETES THE ENTIRE CONTENTS OF SUBDIRECTORY "test" #####
        ####################################################################
        try:
            os.chmod('test',stat.S_IRUSR|stat.S_IWUSR|stat.S_IXUSR)
            for dirpath, dirnames, filenames in os.walk('test'):
                for f in itertools.chain(dirnames, filenames):
                    os.chmod(Path(dirpath)/f,stat.S_IRUSR|stat.S_IWUSR|stat.S_IXUSR)
        except:
            pass
        shutil.rmtree('test', ignore_errors = True)
        mkdir('test')
        mkdir('test/od')
        mkdir('test/tmp')
        os.chdir('test')
        self.__class__.batch += 1
        self.__class__.n = 0
        print(f"TEST {self.batch}: texmf_output_directory={texmf_output_directory}, texmfoutput={texmfoutput}, openin_any={openin_any}, openout_any={openout_any}")
    def __exit__(self, exc_type, exc_value, traceback):
        global texmf_output_directory
        global texmfoutput
        global openin_any
        global openout_any
        texmf_output_directory = self.original_texmf_output_directory
        texmfoutput = self.original_texmfoutput
        openin_any = self.openin_any
        openout_any = self.openout_any
        memoize_extract.texmf_output_directory = self.original_texmf_output_directory
        memoize_extract.texmfoutput = self.original_texmfoutput
        memoize_extract.openin_any = self.openin_any
        memoize_extract.openout_any = self.openout_any
        os.chdir('..')

class TestError(RuntimeError):
    pass
def error(*args):
    raise TestError()
memoize_extract.error = error

def Path(f):
    return pathlib.Path(str(f).replace('/', os.sep))
        
def test(func, *args, unix = None, win = None):
    Test.n += 1
    if unix is not None or win is not None:
        if unix is not None and platform.system() != 'Windows':
            expected_result = unix
        elif win is not None and platform.system() == 'Windows':
             expected_result = win
        else:
            print(f'{Test.n}. ---')
            return
    else:
        args = list(args)
        expected_result = args.pop()
        args = tuple(args)
    call = func.__name__ + "(" + ",".join(str(arg) for arg in args) + ")"
    result = func(*args)
    print(f'{Test.n}. {call} --> {result}')
    assert result == expected_result, f'Expected: {expected_result}'

def create(f, text = ''):
    with open(Path(f), 'w') as fh:
        print(text, file = fh)

_modes = { 'r': stat.S_IRUSR, 'w': stat.S_IWUSR, 'x': stat.S_IXUSR }
def chmod(f, pm_mode):
    assert isinstance(pm_mode, str) and len(pm_mode) == 2
    pm = pm_mode[0]
    assert pm in '+-'
    mode = _modes[pm_mode[1]]
    if pm == '+':
        os.chmod(Path(f), os.stat(f).st_mode | mode)
    elif pm == '-':
        os.chmod(Path(f), os.stat(f).st_mode & ~mode)
    else:
        raise RuntimeError()

def mkdir(d):
    os.mkdir(Path(d))

with Test(None, None):
    none = Path('none.txt')
    cur = Path('cur.txt')
    create(cur)
    
    test(find_in, cur, cur)
    test(find_in, none, none)
    test(find_out, cur, cur)
    test(find_out, none, none)
    
    od_cur = Path('od/cur.txt')
    create(od_cur)
    tmp_cur = Path('tmp/cur.txt')
    create(tmp_cur)
    
    test(find_in, cur, cur)
    test(find_out, cur, cur)
    chmod(cur, '-r')
    test(find_in, cur, cur)
    chmod(cur, '-w')
    test(find_in, cur, cur)
    chmod(cur, '+r')
    test(find_in, cur, cur)

with Test(None, 'tmp'):
    none = Path('none.txt')
    tmp_none = Path('tmp/none.txt')
    tmp = Path('tmp.txt')
    tmp_tmp = Path('tmp/tmp.txt')
    create(tmp_tmp)
    
    test(find_in, none, none)
    test(find_in, tmp, tmp_tmp)
    test(find_out, none, none)
    test(find_out, tmp, tmp)
    
    chmod('.', '-w')
    test(find_in, none, none)
    test(find_in, tmp, tmp_tmp)
    test(find_out, none, unix = tmp_none) # fail on win (no permissions on dir)
    test(find_out, tmp, unix = tmp_tmp) # fail on win (no permissions on dir)
    
    chmod('.', '-r')
    test(find_in, none, none)
    test(find_in, tmp, tmp_tmp)
    test(find_out, none, unix = tmp_none) # fail on win (no permissions on dir)
    test(find_out, tmp, unix = tmp_tmp) # fail on win (no permissions on dir)
    
    chmod('.', '+w')
    test(find_in, none, none)
    test(find_in, tmp, tmp_tmp)
    test(find_out, none, none)
    test(find_out, tmp, tmp)

with Test('od', None):
    none = Path('none.txt')
    od_none = Path('od/none.txt')
    
    cur = Path('cur.txt')
    od_cur = Path('od/cur.txt')
    create(cur)
    
    od = Path('od.txt')
    od_od = Path('od/od.txt')
    create(od_od)
    
    curod = Path('curod.txt')
    od_curod = Path('od/curod.txt')
    create(curod)
    create(od_curod)
    
    test(find_in, none, none)
    test(find_out, none, od_none)
    test(find_in, cur, cur)
    test(find_out, cur, od_cur)
    test(find_in, od, od_od)
    test(find_out, od, od_od)
    test(find_in, curod, od_curod)
    test(find_out, curod, od_curod)
    
    chmod('od', '-w')
    test(find_in, none, none)
    test(find_out, none, od_none)
    chmod('od', '+w')
    chmod('od', '-x')
    test(find_in, od, unix = od) # fail on win --> od_od
    test(find_out, od, od_od)
    test(find_in, curod, unix = curod) # fail on win --> od_curod
    test(find_out, curod, od_curod)
    chmod('od', '+x')
    
    chmod(od_od, '-r')
    test(find_in, od, unix = od) # fail on win --> od_od
    chmod(od_od, '+r')
    chmod(od_od, '-w')
    test(find_out, od, od_od)
    chmod(od_od, '+w')

with Test('od', 'tmp'):
    none = Path('none.txt')
    od_none = Path('od/none.txt')
    tmp_none = Path('tmp/none.txt')
    
    cur = Path('cur.txt')
    od_cur = Path('od/cur.txt')
    tmp_cur = Path('tmp/cur.txt')
    create(cur)
    
    od = Path('od.txt')
    od_od = Path('od/od.txt')
    tmp_od = Path('tmp/od.txt')
    create(od_od)
    
    tmp = Path('tmp.txt')
    od_tmp = Path('od/tmp.txt')
    tmp_tmp = Path('tmp/tmp.txt')
    create(tmp_tmp)
    
    curod = Path('curod.txt')
    od_curod = Path('od/curod.txt')
    tmp_curod = Path('tmp/curod.txt')
    create(curod)
    create(od_curod)
    
    curtmp = Path('curtmp.txt')
    od_curtmp = Path('od/curtmp.txt')
    tmp_curtmp = Path('tmp/curtmp.txt')
    create(curtmp)
    create(tmp_curtmp)
    
    odtmp = Path('odtmp.txt')
    od_odtmp = Path('od/odtmp.txt')
    tmp_odtmp = Path('tmp/odtmp.txt')
    create(od_odtmp)
    create(tmp_odtmp)
    
    curodtmp = Path('curodtmp.txt')
    od_curodtmp = Path('od/curodtmp.txt')
    tmp_curodtmp = Path('tmp/curodtmp.txt')
    create(curodtmp)
    create(od_curodtmp)
    create(tmp_curodtmp)

    test(find_in, none, none)
    test(find_out, none, od_none)
    test(find_in, cur, cur)
    test(find_out, cur, od_cur)
    test(find_in, od, od_od)
    test(find_out, od, od_od)
    test(find_in, tmp, tmp_tmp)
    test(find_out, tmp, od_tmp)
    test(find_in, curod, od_curod)
    test(find_out, curod, od_curod)
    test(find_in, curtmp, curtmp)
    test(find_out, curtmp, od_curtmp)
    test(find_in, odtmp, od_odtmp)
    test(find_out, odtmp, od_odtmp)
    test(find_in, curodtmp, od_curodtmp)
    test(find_out, curodtmp, od_curodtmp)
    
    chmod('od', '-w')
    test(find_out, none, unix = tmp_none) # fail on win --> od_none
    test(find_out, cur, unix = tmp_cur) # fail on win --> od_cur
    test(find_out, od, od_od)
    test(find_out, tmp, unix = tmp_tmp) # fail on win --> od_tmp
    test(find_out, curod, od_curod)
    test(find_out, curtmp, unix = tmp_curtmp) # fail on win --> od_curtmp
    test(find_out, odtmp, od_odtmp)
    test(find_out, curodtmp, od_curodtmp)
    chmod('od', '+w')
    
    chmod(od_od, '-w')
    test(find_in, od, od_od)
    test(find_out, od, tmp_od)
    chmod(od_od, '-r')
    test(find_in, od, unix = od) # fail on win --> od_od
    test(find_out, od, tmp_od)
    chmod(od_od, '+w')
    test(find_in, od, unix = od) # fail on win --> od_od
    test(find_out, od, od_od)
    chmod(od_od, '+r')

# Testing paranoia; more precisely, "_paranoia". We redefine "paranoia_out" to
# return True/False rather than throw an error.
def paranoia_out(f):
    return memoize_extract._paranoia(Path(f), memoize_extract.openout_any)
    
drive = 'C:' if platform.system() == 'Windows' else ''        

# The tests below also holds for TEXMFOUTPUT and TEXMF_OUTPUT_DIRECTORY given
# with a trailing slash.
assert Path(drive + '/home/user/tex/od') == Path(drive + '/home/user/tex/od/')
assert Path(drive + '/tmp') == Path(drive + '/tmp/')
with Test(drive + '/home/user/tex/od', drive + '/tmp', 'p', 'p'):
    test(paranoia_out, drive + '/foo/bar/baz.txt', False)
    test(paranoia_out, 'foo/bar/baz.txt', True)
    test(paranoia_out, '../baz.txt', False)
    test(paranoia_out, 'baz.txt', True)
    
    test(paranoia_out, drive + '/foo/bar/.baz.txt', False)
    test(paranoia_out, 'foo/bar/.baz.txt', unix = False, win = True)
    test(paranoia_out, '../.baz.txt', False)
    test(paranoia_out, '../.baz.txt', False)
    test(paranoia_out, '.baz.txt', unix = False, win = True)
    test(paranoia_out, '.tex', True)
    test(paranoia_out, 'foo/.tex', True)

    test(paranoia_out, drive + '/home/user/tex/od/foo/bar/baz.txt', True)
    test(paranoia_out, drive + '/home/user/tex/od/baz.txt', True)
    test(paranoia_out, drive + '/home/user/tex/odbaz.txt', False)
    test(paranoia_out, drive + '/home/user/tex/baz.txt', False)
    test(paranoia_out, drive + '/home/user/tex/od///./baz.txt', True)
    test(paranoia_out, drive + '/home/user/tex/od/foo/../baz.txt', False)

    test(paranoia_out, drive + '/tmp/foo/bar/baz.txt', True)
    test(paranoia_out, drive + '/tmp/baz.txt', True)
    test(paranoia_out, drive + '/home/user/tex/odbaz.txt', False)
    test(paranoia_out, drive + '/home/user/tex/baz.txt', False)
    test(paranoia_out, drive + '/tmp///./baz.txt', True)
    test(paranoia_out, drive + '/tmp/foo/../baz.txt', False)
    test(paranoia_out, drive + '/tmpbaz.txt', False)

    test(paranoia_out, Path('').cwd().resolve() / 'baz.txt', False)
    test(paranoia_out, Path('').cwd().resolve() / 'foo/baz.txt', False)
    
assert Path('od') == Path('od/')
assert Path('tmp') == Path('tmp/')
with Test('od', 'tmp', 'r', 'r'):
    test(paranoia_out, drive + '/foo/bar/baz.txt', True)
    test(paranoia_out, 'foo/bar/baz.txt', True)
    test(paranoia_out, '../baz.txt', True)
    test(paranoia_out, 'baz.txt', True)
    
    test(paranoia_out, drive + '/foo/bar/.baz.txt', unix = False, win = True)
    test(paranoia_out, 'foo/bar/.baz.txt', unix = False, win = True)
    test(paranoia_out, '../.baz.txt', unix = False, win = True)
    test(paranoia_out, '.baz.txt', unix = False, win = True)
    test(paranoia_out, '.tex', True)
    test(paranoia_out, 'foo/.tex', True)

    test(paranoia_out, drive + '/home/user/tex/od/foo/bar/baz.txt', True)
    test(paranoia_out, drive + '/home/user/tex/od/baz.txt', True)
    test(paranoia_out, drive + '/home/user/tex/odbaz.txt', True)
    test(paranoia_out, drive + '/home/user/tex/baz.txt', True)
    test(paranoia_out, drive + '/home/user/tex/od///./baz.txt', True)
    test(paranoia_out, drive + '/home/user/tex/od/foo/../baz.txt', True)

    test(paranoia_out, drive + '/tmp/foo/bar/baz.txt', True)
    test(paranoia_out, drive + '/tmp/baz.txt', True)
    test(paranoia_out, drive + '/home/user/tex/odbaz.txt', True)
    test(paranoia_out, drive + '/home/user/tex/baz.txt', True)
    test(paranoia_out, drive + '/tmp///./baz.txt', True)
    test(paranoia_out, drive + '/tmp/foo/../baz.txt', True)

    test(paranoia_out, Path('').cwd().resolve() / 'baz.txt', True)
    test(paranoia_out, Path('').cwd().resolve() / 'foo/baz.txt', True)

with Test('od', 'tmp', 'a', 'a'):
    test(paranoia_out, drive + '/foo/bar/baz.txt', True)
    test(paranoia_out, 'foo/bar/baz.txt', True)
    test(paranoia_out, '../baz.txt', True)
    test(paranoia_out, '../baz.txt', True)
    test(paranoia_out, 'baz.txt', True)
    test(paranoia_out, drive + '/foo/bar/.baz.txt', True)
    test(paranoia_out, 'foo/bar/.baz.txt', True)
    test(paranoia_out, '../.baz.txt', True)
    test(paranoia_out, '../.baz.txt', True)
    test(paranoia_out, '.baz.txt', True)
    test(paranoia_out, '.tex', True)
    test(paranoia_out, 'foo/.tex', True)

    test(paranoia_out, drive + '/home/user/tex/od/foo/bar/baz.txt', True)
    test(paranoia_out, drive + '/home/user/tex/od/baz.txt', True)
    test(paranoia_out, drive + '/home/user/tex/odbaz.txt', True)
    test(paranoia_out, drive + '/home/user/tex/baz.txt', True)
    test(paranoia_out, drive + '/home/user/tex/od///./baz.txt', True)
    test(paranoia_out, drive + '/home/user/tex/od/foo/../baz.txt', True)

    test(paranoia_out, drive + '/tmp/foo/bar/baz.txt', True)
    test(paranoia_out, drive + '/tmp/baz.txt', True)
    test(paranoia_out, drive + '/home/user/tex/odbaz.txt', True)
    test(paranoia_out, drive + '/home/user/tex/baz.txt', True)
    test(paranoia_out, drive + '/tmp///./baz.txt', True)
    test(paranoia_out, drive + '/tmp/foo/../baz.txt', True)

    test(paranoia_out, Path('').cwd().resolve() / 'baz.txt', True)
    test(paranoia_out, Path('').cwd().resolve() / 'foo/baz.txt', True)

with Test('od', '../tmp', 'p', 'p'):
    test(paranoia_out, drive + '/foo/bar/baz.txt', False)
    test(paranoia_out, 'foo/bar/baz.txt', True)
    test(paranoia_out, '../baz.txt', False)
    test(paranoia_out, 'baz.txt', True)
    
    test(paranoia_out, drive + '/foo/bar/.baz.txt', False)
    test(paranoia_out, 'foo/bar/.baz.txt', unix = False, win = True)
    test(paranoia_out, '../.baz.txt', False)
    test(paranoia_out, '../.baz.txt', False)
    test(paranoia_out, '.baz.txt', unix = False, win = True)
    test(paranoia_out, '.tex', True)
    test(paranoia_out, 'foo/.tex', True)

    test(paranoia_out, 'od/foo/bar/baz.txt', True)
    test(paranoia_out, 'od/baz.txt', True)
    test(paranoia_out, 'odbaz.txt', True) # in current dir
    test(paranoia_out, './//./baz.txt', True)
    test(paranoia_out, 'foo/../baz.txt', False)

    test(paranoia_out, '../tmp/foo/bar/baz.txt', False)
    test(paranoia_out, '../tmp/baz.txt', False)
    test(paranoia_out, drive + '/home/user/tex/odbaz.txt', False)
    test(paranoia_out, drive + '/home/user/tex/baz.txt', False)
    test(paranoia_out, '../tmp///./baz.txt', False)
    test(paranoia_out, '../tmp/foo/../baz.txt', False)

    test(paranoia_out, Path('').cwd().resolve() / 'baz.txt', False)
    test(paranoia_out, Path('').cwd().resolve() / 'foo/baz.txt', False)
    test(paranoia_out, texmfoutput.resolve() / 'baz.txt', False)
    test(paranoia_out, texmf_output_directory.resolve() / 'baz.txt', False)

with Test(None, None, 'p', 'p'):
    tmp = Path('tmp')
    mkdir('tmp/foo')
    mkdir('tmp/foo/bar')
    chmod(tmp, '-w')
    test(access_out, tmp / 'foo', True)
    test(access_out, tmp / 'foo/bar', True)
    test(access_out, tmp / 'foo/bar/baz', True)
    test(access_out, tmp / 'foo/bar/..', True)
    test(access_out, tmp / 'foo/bar/../..', False)
