#!/bin/env python

# from IPython import embed

import argparse, fileinput, os, os.path, re
from pdfrw import PdfReader, PdfWriter

memoized_re = re.compile(r'\\([a-zA-Z]+) ' + r'{(.*?)}' * 10 + r'%')
prefix_re = re.compile(r'% *memo filename prefix *= *{(.*?)} *')
suffix_re = re.compile(r'% *memo filename suffix *= *{(.*?)} *')

class Pages(dict):
    def __missing__(self, filename):
        temp = self[filename] = (PdfReader(filename).pages, set())
        return temp

class Memoized:
    def __init__(self, groups, prefix, suffix):
        self.command, self.md5, self.pdf_filename, self.page_n, \
            self.wd, self.ht, self.dp, \
            self.padding_left, self.padding_bottom, \
            self.padding_top, self.padding_right = \
                groups
        self.page_n = int(self.page_n)
        self.prefix = prefix
        self.suffix = suffix

    @property
    def md5_pdf_filename(self):
        return os.path.basename(self.prefix) + self.md5 + self.suffix + ".pdf"
        
    def __str__(self):
        return fr'\{self.command} {{{self.md5}}}{{{self.pdf_filename}}}{{{self.page_n}}}{{{self.wd}}}{{{self.ht}}}{{{self.dp}}}{{{self.padding_left}}}{{{self.padding_bottom}}}{{{self.padding_top}}}{{{self.padding_right}}}'

def process_mmz(mmz, args):
    with fileinput.input(args.mmz) as mmz:
        prefix = args.prefix
        suffix = args.suffix
        for mmz_line in mmz:
            memoized = memoized_re.match(mmz_line)
            if memoized:
                yield Memoized(memoized.groups(), prefix, suffix)
            elif prefix_re.match(mmz_line):
                prefix = prefix_re.match(mmz_line)[1]
            elif suffix_re.match(mmz_line):
                suffix = suffix_re.match(mmz_line)[1]
            else:
                raise RuntimeError(mmz_line)

def split(args):
    pages = Pages()
    for m in process_mmz(args.mmz, args):
        if m.command != 'memoized':
            continue
        out_basename = os.path.join(args.mmz_path, m.prefix + m.md5 + m.suffix)
        if args.verbose:
            print(os.path.join(args.mmz_path, m.pdf_filename), m.page_n,
                  '-->', out_basename + ".pdf")
        memo_pdf = PdfWriter(out_basename + '.pdf')
        memo_pdf.addpage(pages[m.pdf_filename][0][m.page_n-1])
        memo_pdf.write()
        pages[m.pdf_filename][1].add(m.page_n-1)
        m.pdf_filename = m.md5_pdf_filename
        with open(out_basename, 'w') as memo:
            print(fr'{m}%', file = memo)
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
    for m in process_mmz(args.mmz, args):
        if m.command != 'usedmemoized':
            continue
        memo_filename, _ = os.path.splitext(m.pdf_filename)
        os.remove(memo_filename)
        os.remove(m.pdf_filename)
        os.remove(memo_filename + '.log')
        if args.verbose:
            print(f'Removed {memo_filename}, plus its .log and .pdf')

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

parser.add_argument('mmz', help='.mmz file')

args = parser.parse_args()
args.mmz_path = os.path.dirname(args.mmz)
args.func(args)
