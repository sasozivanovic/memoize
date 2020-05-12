#!/bin/env python

import argparse, fileinput, re
from pdfrw import PdfReader, PdfWriter

parser = argparse.ArgumentParser(description='Split the memos off the main pdf.')
parser.add_argument('mmz', help='.mmz file')
parser.add_argument('rest_filename', nargs = '?', help='Where to save the rest (empty means inline)')
parser.add_argument('--prefix', help='memo filename prefix')
parser.add_argument('--suffix', help='memo filename suffix')
parser.add_argument('--rest', action = 'store_true',
                    help='Should we save the rest as well?')
parser.add_argument('--pdf', help='main pdf')

args = parser.parse_args()
print(args)


justmemoizedto_re = re.compile(r'\\justmemoizedto {(.*?)}%')
justmemoized_re = re.compile(r'\\justmemoized {(.*?)}%')
memoized_re = re.compile(r'\\memoized {(.*?)}{(.*?)}{(.*?)}{(.*?)}%')

with fileinput.input(args.mmz) as mmz:
    justmemoizedto = justmemoizedto_re.match(next(mmz))[1]
    justmemoizedto = args.pdf if args.pdf else justmemoizedto
    # todo: get these from .mmz
    prefix = args.prefix
    suffix = args.suffix

    pages = PdfReader(justmemoizedto).pages
    memos = set()
    for mmz_line in mmz:
        justmemoized = justmemoized_re.match(mmz_line)[1]
        basename = prefix + justmemoized + suffix
        updated_memo = []
        with open(basename) as memo:
            for memo_line in memo:
                md5, pdf_filename, page_n, dpth = \
                    memoized_re.match(memo_line).group(1,2,3,4)
                assert justmemoized == md5
                # assert justmemoizedto == pdf_filename
                page_n = int(page_n) - 1

                print(justmemoizedto, page_n, '-->', basename + ".pdf")
                
                memo_pdf = PdfWriter(basename + '.pdf')
                memo_pdf.addpage(pages[page_n])
                memo_pdf.write()
                memos.add(page_n)

                updated_memo.append(fr'\memoized {{{md5}}}{{{"chapters/" + basename + ".pdf"}}}{{{1}}}{{{dpth}}}%')


        with open(basename, 'w') as memo:
            for memo_line in updated_memo:
                print(memo_line, file = memo)
            
    if args.rest:
        out_pdf = PdfWriter(args.rest_filename if args.rest_filename else justmemoizedto)
        for n, page in enumerate(pages):
            if n not in memos:
               out_pdf.addpage(pages[n])
        out_pdf.write()
