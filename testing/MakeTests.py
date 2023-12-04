#!/usr/bin/env python

from pathlib import Path
import filecmp, os, collections, argparse, itertools, stat, shutil, subprocess, shutil, glob, braceexpand, re, platform

TestData = collections.namedtuple('Test', ['targets', 'deps', 'wds'])

def Test(targets, deps, title = '', remark = '', work_dirs = ('test', 'tmp')):
    if not args.targets or targets[0] in args.targets or 'success/' + targets[0] in args.targets:
        targets[0] = f'success/{targets[0]}'
        print(f'\n===========================  {title}  ===========================\n{targets} <-- {deps}')
        if remark:
            print(remark)
        if not args.always_make and \
           all(Path(target).exists() for target in targets) and \
           all(newer(name, dep) for name in targets for dep in deps):
            print('Up to date.')
        else:
            for d in work_dirs:
                recursive_chmod('+w', d)
                shutil.rmtree(d, ignore_errors = True)
                Path(d).mkdir(parents = True, exist_ok = True)
            yield TestData(targets, deps, work_dirs)
            Path(targets[0]).touch()
        
def newer(f1, f2):
    try:
        s1 = os.stat(f1)
    except:
        return False
    s2 = os.stat(f2)
    return s1.st_mtime >= s2.st_mtime

def echo(func, *args, **kwargs):
    print(func if isinstance(func, str) else func.__qualname__,
          "(",
          ", ".join(filter(None,(
              ", ".join(repr(arg) for arg in args),
              ", ".join(f"{key} = {repr(value)}" for key, value in kwargs.items()),
          ))),
          ")",
          sep = '')

def expand(*args):
    for arg in args:
        for b in braceexpand.braceexpand(arg):
            for g in glob.glob(b):
                yield g

def diff(*args):
    fn1, fn2 = expand(*args)
    echo(diff, fn1, fn2)
    with open(fn1) as f1:
        lines1 = f1.readlines()
    with open(fn2) as f2:
        lines2 = f2.readlines()
    cmp = lines1 == lines2
    if not cmp and platform.system() != 'Windows':
        env = os.environ
        env.update(GIT_PAGER = 'cat')
        subprocess.run('git diff --no-index --word-diff=color --word-diff-regex=.'.split()
                       + [fn1,fn2], env = env)
    return cmp

_modes = { 'r': stat.S_IRUSR, 'w': stat.S_IWUSR, 'x': stat.S_IXUSR }
def chmod(pm_mode, f):
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

def recursive_chmod(pm_mode, path):
    chmod(pm_mode, path)
    for f in Path(path).rglob('*'):
        chmod(pm_mode, f)

def mv(*args):
    echo(mv, *args)
    dst = args[-1]
    for src in expand(args[0:-1]):
        shutil.move(src, dst)

def cp(*args):
    echo(cp, *args)
    dst = args[-1]
    for src in expand(args[0:-1]):
        if Path(src).is_dir():
            shutil.copytree(src, dst, dirs_exist_ok = True)
        else:
            shutil.copy(src, dst)

def run(args, *, env = {}, **kwargs):
    if isinstance(args, str):
        args = args.split()
    if args[0].endswith('.py'):
        args[0] = str(Path.cwd() / args[0])
        args.insert(0, 'python')
    elif args[0].endswith('.pl'):
        args[0] = str(Path.cwd() / args[0])
        args.insert(0, 'perl')
    if env:
        echo(run, args, env = env, **kwargs)
        environ = os.environ
        environ.update((key,str(value)) for key,value in env.items())
        kwargs.update(env = environ)
    else:
        echo(run, args, **kwargs)
    print(
        " ".join(f'{key}={value}' for key, value in env.items()),
        ' ' if env else '',
        args if isinstance(args, str) else " ".join(args),
        sep = '',
    )
    rc = subprocess.run(args, **kwargs).returncode
    print(f"Exit code: {rc}")
    return rc == 0

def exists(path):
    echo(exists, path)
    return Path(path).exists()

def mkdir(path, **kwargs):
    echo(mkdir, path, **kwargs)
    return Path(path).mkdir(**kwargs)

def grep(regex, *files):
    echo(grep, regex, *files)
    r = re.compile(regex)
    for fn in expand(files):
        with open(fn) as f:
            for line in f:
                if r.match(line):
                    yield line

def rm(*files):
    echo(rm, *files)
    for fn in expand(*files):
        Path(fn).unlink()

parser = argparse.ArgumentParser()
parser.add_argument('-B', '--always-make', action = 'store_true')
parser.add_argument('targets', nargs = '*')
args = parser.parse_args()

for pyl in ('py', 'pl'):
    for test in Test(
            [f'unittest-memoize-extract.{pyl}'],
            [f'unittest-memoize-extract.{pyl}', f'memoize-extract.{pyl}'],
            'Unit tests'):
        assert run(f'unittest-memoize-extract.{pyl}'.split())
            
for test in Test(['nomemodir', 'build/nomemodir/doc.pdf'], ['src/nomemodir/doc.tex'],
                 'Compiling sources', work_dirs = ['build/nomemodir']):
    cp('src/nomemodir/doc.tex', 'build/nomemodir')
    assert run('pdflatex -interaction batchmode doc'.split(), cwd = 'build/nomemodir')
    assert diff('{expected/nomemodir,build/nomemodir}/doc.mmz')
    assert diff('{expected/nomemodir,build/nomemodir}/doc.799CD96D5634EBEB7E30191285AF4082.memo')
    assert diff('{expected/nomemodir,build/nomemodir}/doc.799CD96D5634EBEB7E30191285AF4082-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.memo')
    assert diff('{expected/nomemodir,build/nomemodir}/doc.7DBC7B29C0C49BCFD5C4A18740E06E80.memo')
    assert diff('{expected/nomemodir,build/nomemodir}/doc.7DBC7B29C0C49BCFD5C4A18740E06E80-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.memo')


for test in Test(['memodir', 'build/memodir/doc.pdf'], ['src/memodir/doc.tex'],
                 'Compiling sources', work_dirs = ['build/memodir']):
    cp('src/memodir/doc.tex', 'build/memodir')
    assert run('pdflatex -interaction batchmode doc'.split(), cwd = 'build/memodir')
    assert diff('{expected/memodir,build/memodir}/doc.mmz')
    assert diff('{expected/memodir,build/memodir}/doc.memo.dir/799CD96D5634EBEB7E30191285AF4082.memo')
    assert diff('{expected/memodir,build/memodir}/doc.memo.dir/799CD96D5634EBEB7E30191285AF4082-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.memo')
    assert diff('{expected/memodir,build/memodir}/doc.memo.dir/7DBC7B29C0C49BCFD5C4A18740E06E80.memo')
    assert diff('{expected/memodir,build/memodir}/doc.memo.dir/7DBC7B29C0C49BCFD5C4A18740E06E80-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.memo')


for pyl in ('py', 'pl'):
    inexisting_absolute = ('C:\\' if platform.system() == 'Windows' else '/') + 'inexisting'
    
    for test in Test([f'extract-nomemodir.{pyl}'],
                     [f'memoize-extract.{pyl}', f'build/nomemodir/doc.pdf'],
                     'Extract from a [nomemodir] document'):
        cp('build/nomemodir', 'test')
        assert run(f'memoize-extract.{pyl} doc.mmz'.split(), cwd = 'test')
        assert diff('expected/extract-nomemodir/doc.mmz', 'test/doc.mmz')
        assert exists('test/doc.799CD96D5634EBEB7E30191285AF4082-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.pdf')
        assert exists('test/doc.7DBC7B29C0C49BCFD5C4A18740E06E80-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.pdf')

    for test in Test([f'extract-memodir.{pyl}'],
                     [f'memoize-extract.{pyl}', f'build/memodir/doc.pdf'],
                     'Extract from a [memodir] document',
                     "Also test that memoize-extract can be called without .mmz suffix"):
        cp('build/memodir', 'test')
        assert run(f'memoize-extract.{pyl} doc.mmz'.split(), cwd = 'test')
        assert diff('expected/extract-memodir/doc.mmz', 'test/doc.mmz')
        assert exists('test/doc.memo.dir/799CD96D5634EBEB7E30191285AF4082-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.pdf')
        assert exists('test/doc.memo.dir/7DBC7B29C0C49BCFD5C4A18740E06E80-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.pdf')
    

    for test in Test([f'extract-from-subdir.{pyl}'],
                     [f'memoize-extract.{pyl}', f'build/nomemodir/doc.pdf'],
                     ".mmz in a parent directory without -k"):
        cp('build/nomemodir', 'test')
        mkdir('test/foo')
        assert not run(f'memoize-extract.{pyl} ../doc.mmz'.split(), cwd = 'test/foo')
    
        
    for test in Test([f'extract-from-subdir-no-memos.{pyl}'],
                     [f'memoize-extract.{pyl}', f'build/nomemodir/doc.pdf'],
                     ".mmz in a parent directory with -k",
                     "This fails because the associated .memo files don't exist"):
        cp('build/nomemodir', 'test')
        mkdir('test/foo')
        assert not run(f'memoize-extract.{pyl} -k ../doc.mmz'.split(), cwd = 'test/foo',
                       env = {'TEXMFOUTPUT': inexisting_absolute} # make sure the memos are not in the temp directory
                       )
        
    for test in Test([f'extract-from-subdir-memos.{pyl}'],
                     [f'memoize-extract.{pyl}', f'build/nomemodir/doc.pdf'],
                     ".mmz in a parent directory with -k",
                     "Successful because we first move the associated .memo files into 'foo'"):
        cp('build/nomemodir', 'test')
        mkdir('test/foo')
        mv('test/doc.*.memo', 'test/foo')
        assert run(f'memoize-extract.{pyl} -k ../doc.mmz'.split(), cwd = 'test/foo',
                   env = {'TEXMFOUTPUT': inexisting_absolute} # make sure the memos are not in the temp directory
                   )
        
    for test in Test([f'extract-from-parallel-dir.{pyl}'],
                     [f'memoize-extract.{pyl}', f'build/nomemodir/doc.pdf'],
                     ".mmz in a parallel directory", "Fails without --keep"):
        cp('build/nomemodir', 'test')
        assert not run(f'memoize-extract.{pyl} ../test/doc.mmz'.split(), cwd = 'tmp')
    
        
    for test in Test([f'extract-from-subdir-prune.{pyl}'],
                     [f'memoize-extract.{pyl}', f'build/nomemodir/doc.pdf'],
                     ".mmz in a parallel directory", "Fails due to --prune"):
        cp('build/nomemodir', 'test')
        mkdir('test/foo')
        assert not run(f'memoize-extract.{pyl} -kp ../doc.mmz'.split(), cwd = 'test/foo')
    
    for test in Test([f'extract-to-tmp.{pyl}'],
                     [f'memoize-extract.{pyl}', f'build/nomemodir/doc.pdf'],
                     "Output to a temporary directory", "The current directory is non-writable"):
        cp('build/nomemodir', 'test')
        chmod('-w', 'test')
        assert run(f'memoize-extract.{pyl} doc.mmz'.split(),
                   cwd = 'test', env = {'TEXMFOUTPUT': str(Path.cwd() / 'tmp')})
    
    for test in Test([f'mkdir.{pyl}'],
                     [f'memoize-extract.{pyl}'],
                     "--mkdir", "(a) Create a subdir .. OK; (b) create a parallel dir .. FAIL; (c) create a subsubdir .. OK; (d) create a subdir referred to using \"..\" .. FAIL"):
        assert run(f'memoize-extract.{pyl} --mkdir foo'.split(), cwd = 'test')
        assert not run(f'memoize-extract.{pyl} --mkdir ../bar'.split(), cwd = 'test/foo')
        assert run(f'memoize-extract.{pyl} --mkdir tmp/foo'.split())
        assert not run(f'memoize-extract.{pyl} --mkdir tmp/foo/../bar'.split())

    if platform.system() != 'Windows': # no directory permissions
        for test in Test([f'compile-and-extract-to-tmp.{pyl}'],
                         [f'memoize-extract.{pyl}', f'src/nomemodir/doc.tex'],
                         "Compile and extract to a temporary directory",
                         "Current directory is not writable; also test that memoize-extract can be called with .tex suffix"):
            cp('src/nomemodir/doc.tex', 'test')
            chmod('-w', 'test')
            assert run('pdflatex -interaction batchmode doc'.split(), cwd = 'test',
                       env = {'TEXMFOUTPUT': str(Path.cwd() / 'tmp')})
            cwd = str(Path.cwd())
            diff(f'{{expected/nomemodir,{cwd}/tmp}}/doc.mmz')
            diff(f'{{expected/nomemodir,{cwd}/tmp}}/doc.799CD96D5634EBEB7E30191285AF4082.memo')
            diff(f'{{expected/nomemodir,{cwd}/tmp}}/doc.799CD96D5634EBEB7E30191285AF4082-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.memo')
            diff(f'{{expected/nomemodir,{cwd}/tmp}}/doc.7DBC7B29C0C49BCFD5C4A18740E06E80.memo')
            diff(f'{{expected/nomemodir,{cwd}/tmp}}/doc.7DBC7B29C0C49BCFD5C4A18740E06E80-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.memo')
            assert run(f'memoize-extract.{pyl} doc.tex'.split(), cwd = 'test',
                       env = {'TEXMFOUTPUT': str(Path.cwd() / 'tmp')})
            exists(f'{cwd}/tmp/doc.799CD96D5634EBEB7E30191285AF4082-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.pdf')
            exists(f'{cwd}/tmp/doc.7DBC7B29C0C49BCFD5C4A18740E06E80-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.pdf')
        

    for test in Test([f'compile-and-extract-to-od.{pyl}'],
                     [f'memoize-extract.{pyl}', f'src/nomemodir/doc.tex'],
                     "Compile and extract to output directory"):
        cp('src/nomemodir/doc.tex', 'test')
        mkdir('test/od')
        assert run('pdflatex -interaction batchmode -output-directory=od doc'.split(),
                   cwd = 'test')
        diff('{expected/nomemodir,test/od}/doc.mmz')
        diff('{expected/nomemodir,test/od}/doc.799CD96D5634EBEB7E30191285AF4082.memo')
        diff('{expected/nomemodir,test/od}/doc.799CD96D5634EBEB7E30191285AF4082-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.memo')
        diff('{expected/nomemodir,test/od}/doc.7DBC7B29C0C49BCFD5C4A18740E06E80.memo')
        diff('{expected/nomemodir,test/od}/doc.7DBC7B29C0C49BCFD5C4A18740E06E80-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.memo')
        assert run(f'memoize-extract.{pyl} doc.tex'.split(), cwd = 'test',
                   env = {'TEXMF_OUTPUT_DIRECTORY': 'od'})
        exists('test/od/doc.799CD96D5634EBEB7E30191285AF4082-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.pd')
        exists('test/od/doc.7DBC7B29C0C49BCFD5C4A18740E06E80-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.pd')
        

    if platform.system() != 'Windows': # no permissions on dirs, no TEXMFOUTPUT in MiKTeX
        for test in Test([f'extract-to-notmp.{pyl}'],
                         [f'memoize-extract.{pyl}', f'build/nomemodir/doc.pdf'],
                         "Output to a non-existing temporary directory",
                         "We end up attempting to write to a readonly current directory and get a permission error"):
            cp('build/nomemodir/*', 'test')
            chmod('-w', 'test')
            assert not run(f'memoize-extract.{pyl} doc.mmz'.split(),
                           cwd = 'test',
                           env = {'TEXMFOUTPUT': str(Path.cwd() / 'tmp/does/not/exist')})

        for test in Test([f'extract-to-bad-relative-tmp.{pyl}'],
                         [f'memoize-extract.{pyl}', f'build/nomemodir/doc.pdf'],
                         'Output to a temporary directory involving ".."',
                         "Paranoia kicks in"):
            cp('build/nomemodir/*', 'test')
            chmod('-w', 'test')
            assert not run(f'memoize-extract.{pyl} doc.mmz'.split(),
                           cwd = 'test', env = {'TEXMFOUTPUT': '../tmp'})

    for test in Test([f'mmz-log.{pyl}'],
                     [f'memoize-extract.{pyl}', f'build/nomemodir/doc.pdf'],
                     "Create .mmz.log for LaTeX"):
        cp('build/nomemodir/*', 'test')
        assert run(f'memoize-extract.{pyl} -F latex doc.mmz'.split(), cwd = 'test')
        assert exists('test/doc.mmz.log')
        print('Expecting 4 lines in: ', end = '')
        assert sum(1 for _ in grep(r'^\\PackageInfo', 'test/doc.mmz.log')) == 4
        print('Expecting 1 line in: ', end = '')
        assert sum(1 for _ in grep(r'^\\endinput$', 'test/doc.mmz.log')) == 1

        
    for test in Test([f'extract-no-memos.{pyl}'],
                     [f'memoize-extract.{pyl}', f'build/nomemodir/doc.pdf'],
                     "Removed memo files"):
        cp('build/nomemodir/*', 'test')
        rm('test/doc.799CD96D5634EBEB7E30191285AF4082.memo', 'test/doc.7DBC7B29C0C49BCFD5C4A18740E06E80-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.memo')
        assert not run(f'memoize-extract.{pyl} doc'.split(), cwd = 'test',
                       env = {'TEXMFOUTPUT': str(Path.cwd() / 'tmp/does/not/exist')})
