#!/bin/env python

from IPython import embed

import argparse, fileinput, os, os.path, re
from pdfrw import PdfReader, PdfWriter

parser = argparse.ArgumentParser(description='Split the memos off the main pdf.')
parser.add_argument('mmz', help='.mmz file')
parser.add_argument('--prefix', help='memo filename prefix')
parser.add_argument('--suffix', help='memo filename suffix')
parser.add_argument('--prune', action = 'store_true',
                    help='Should we prune the original file?')
parser.add_argument('--pdf', help='main pdf')
parser.add_argument('--verbose', '-v', action = 'store_true')

args = parser.parse_args()

mmz_path = os.path.dirname(args.mmz)
prefix = args.prefix
suffix = args.suffix

memoized_re = re.compile(r'\\memoized {(.*?)}{(.*?)}{(.*?)}{(.*?)}{(.*?)}{(.*?)}%')
prefix_re = re.compile(r'% *memo filename prefix *= *{(.*?)} *')
suffix_re = re.compile(r'% *memo filename suffix *= *{(.*?)} *')

class Pages(dict):
    def __missing__(self, filename):
        temp = self[filename] = (PdfReader(filename).pages, set())
        return temp
pages = Pages()

with fileinput.input(args.mmz) as mmz:
    for mmz_line in mmz:
        if memoized := memoized_re.match(mmz_line):
            md5, pdf_filename, page_n, wd, ht, dp = \
                memoized_re.match(mmz_line).groups()
            page_n = int(page_n) - 1
            out_basename = os.path.join(mmz_path, prefix + md5 + suffix)

            if args.verbose:
                print(os.path.join(mmz_path, pdf_filename), page_n + 1,
                      '-->', out_basename + ".pdf")
                
            memo_pdf = PdfWriter(out_basename + '.pdf')
            memo_pdf.addpage(pages[pdf_filename][0][page_n])
            memo_pdf.write()
            pages[pdf_filename][1].add(page_n)
            
            with open(out_basename, 'w') as memo:
                print(fr'\memoized {{{md5}}}'
                      fr'{{{prefix_basename + md5 + suffix + ".pdf"}}}{{{1}}}'
                      fr'{{{wd}}}{{{ht}}}{{{dp}}}%', file = memo)

        elif affix := prefix_re.match(mmz_line):
            prefix = affix[1]
            prefix_basename = os.path.basename(prefix)
        elif affix := suffix_re.match(mmz_line):
            suffix = affix[1]

        else:
            raise RuntimeError(mmz_line)

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
os.rename(args.mmz, args.mmz + '.bak')
