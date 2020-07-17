#!/bin/env python

import argparse, fileinput, os, os.path, collections
# from IPython import embed

from pdfrw import PdfReader, PdfWriter
from pyparsing import Word, alphas, nestedExpr, CharsNotIn, \
    Suppress, ZeroOrMore, Group, Optional, delimitedList


# a rudimentary .memo parser

Command = Word('\\', alphas)
Argument = nestedExpr('{', '}')
Key = CharsNotIn('=,')
Val = CharsNotIn('=,')
Whitespace = Suppress(ZeroOrMore(' '))
Keyval = Group(Whitespace + Key + Optional(
    Whitespace + Suppress('=') + Whitespace + Val, default = None))
Keylist = delimitedList(Keyval)

class CommandCall:

    def __init__(self, line):
        self.command = Command.parseString(line)[0]
        self.arguments = []
        for _, start, end in Argument.scanString(line):
            self.arguments.append(collections.OrderedDict(
                Keylist.parseString(line[start+1:end-1]).asList()))

    def __str__(self):
        return self.command + ' ' + "".join(
            '{' + 
            ", ".join(
                key if val is None else f'{key}={val}'
                for key, val in argument.items()
            )
            + '}'
            for argument in self.arguments
        ) + '%'

def process_mmz(mmz, args):
    with fileinput.input(args.mmz) as mmz:
        memoizeset = {
            'memo filename prefix': args.prefix,
            'memo filename suffix': args.suffix
        }
        for mmz_line in mmz:
            command_call = CommandCall(mmz_line)
            if command_call.command == '\memoizeset':
                memoizeset.update(command_call.arguments[0])
                continue
            else:
                yield command_call, memoizeset

class Pages(dict):
    def __missing__(self, filename):
        temp = self[filename] = (PdfReader(filename).pages, set())
        return temp


def unbrace(s):
    return s[1:-1] if s.startswith('{') and s.endswith('}') else s

def brace(s):
    return '{' + s + '}'

def split(args):
    pages = Pages()
    for cc, ms in process_mmz(args.mmz, args):
        if cc.command != '\\memoized':
            continue
        md5 = list(cc.arguments[0].keys())[0]
        m = cc.arguments[1]
        out_basename = os.path.join(args.mmz_path, unbrace(ms['memo filename prefix']) + md5 + unbrace(ms['memo filename suffix']))
        if 'disable' not in m:
            if args.verbose:
                print(os.path.join(args.mmz_path, unbrace(m['filename'])), m['page'],
                      '-->', out_basename + ".pdf")
            memo_pdf = PdfWriter(out_basename + '.pdf')
            memo_pdf.addpage(pages[unbrace(m['filename'])][0][int(m['page'])-1])
            memo_pdf.write()
            pages[unbrace(m['filename'])][1].add(int(m['page'])-1)
            m['filename'] = brace(os.path.basename(unbrace(ms['memo filename prefix'])) + md5 + unbrace(ms['memo filename suffix']) + ".pdf")
        with open(out_basename, 'w') as memo:
            print(cc, file = memo)
    if args.prune:
        for filename, (reader_pages, extracted_pages) in pages.items():
            if args.verbose:
                print(f'Pruning', filename, '-- keeping pages: ', end = '')
            out_pdf = PdfWriter(filename)
            for n, page in enumerate(reader_pages):
                if n not in extracted_pages:
                   out_pdf.addpage(reader_pages[n])
                   if args.verbose:
                       print(f'{n+1}, ', end = '')
            out_pdf.write()
            if args.verbose:
                print()
    if args.verbose:
        print(f'{args.mmz} is empty now, backup in {args.mmz+".bak"}')
    # todo: don't remove once we have the option to ignore .mmz in .sty
    os.rename(args.mmz, args.mmz + '.bak')

def remove_memos(args):
    for cc, ms in process_mmz(args.mmz, args):
        if cc.command != '\\usedmemoized':
            continue
        m = cc.arguments[1]
        memo_filename, _ = os.path.splitext(unbrace(m['filename']))
        for fn in (memo_filename, unbrace(m['filename']), memo_filename + '.log'):
            try:
                os.remove(fn)
                if args.verbose:
                    print(f'Removed {memo_filename}, plus its .log and .pdf')
            except FileNotFoundError:
                pass

def adhoc(args):
    with fileinput.input(args.mmz) as mmz:
        for line in mmz:
            print(line.strip())
            print(CommandCall(line))
            print()
            

parser = argparse.ArgumentParser(description='Manage memoize memos.')
parser.add_argument('--verbose', '-v', action = 'store_true')
parser.add_argument('--prefix', help='memo filename prefix')
parser.add_argument('--suffix', help='memo filename suffix')

subparsers = parser.add_subparsers(title = 'Commands')

parser_split = subparsers.add_parser('split', help = 'Split the memos off the pdf generated in the last compilation')
parser_split.add_argument('--prune', action = 'store_true', help='Should we prune the original file?')
parser_split.set_defaults(func=split)

parser_remove = subparsers.add_parser('remove', aliases = ['delete'], help = 'Remove the memos used in the last compilation')
parser_remove.set_defaults(func=remove_memos)

parser_adhoc = subparsers.add_parser('adhoc')
parser_adhoc.set_defaults(func=adhoc)

parser.add_argument('mmz', help='.mmz file')

args = parser.parse_args()
args.mmz_path = os.path.dirname(args.mmz)
args.func(args)
