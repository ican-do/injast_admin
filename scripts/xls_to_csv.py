#!/usr/bin/env python3
"""تبدیل .xls به CSV با UTF-8 BOM — سلول‌های ادغام باز می‌شوند."""
import csv
import io
import sys


def _build_cell_cache(sheet, book):
    cache = {}
    for r in range(sheet.nrows):
        for c in range(sheet.ncols):
            cache[(r, c)] = sheet.cell_value(r, c)

    for rlo, rhi, clo, chi in sheet.merged_cells:
        if rlo >= sheet.nrows or clo >= sheet.ncols:
            continue
        top_val = sheet.cell_value(rlo, clo)
        for r in range(rlo, rhi):
            for c in range(clo, chi):
                if r < sheet.nrows and c < sheet.ncols:
                    cache[(r, c)] = top_val
    return cache


def _cell_text(sheet, book, r, c, cache, xlrd_mod):
    raw = cache.get((r, c), sheet.cell_value(r, c))
    if (r, c) not in cache and sheet.cell_type(r, c) == xlrd_mod.XL_CELL_DATE:
        try:
            dt = xlrd_mod.xldate_as_datetime(raw, book.datemode)
            return f"{dt.year}/{dt.month:02d}/{dt.day:02d}"
        except Exception:
            return str(raw).strip()
    if raw is None:
        return ""
    if isinstance(raw, float) and raw == int(raw):
        return str(int(raw))
    return str(raw).strip()


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: xls_to_csv.py <file.xls>", file=sys.stderr)
        return 2
    path = sys.argv[1]
    try:
        import xlrd  # noqa: PLC0415
    except ImportError:
        print("xlrd not installed", file=sys.stderr)
        return 1

    try:
        try:
            book = xlrd.open_workbook(path, formatting_info=True)
        except Exception:
            book = xlrd.open_workbook(path, formatting_info=False)
        sheet = book.sheet_by_index(0)
        if sheet.nrows < 1:
            sys.stdout.buffer.write(b"")
            return 0

        headers = [str(sheet.cell_value(0, c)).strip() for c in range(sheet.ncols)]
        cache = _build_cell_cache(sheet, book)

        buf = io.StringIO()
        writer = csv.writer(buf, delimiter=",", quoting=csv.QUOTE_MINIMAL, lineterminator="\n")
        writer.writerow(headers)
        for r in range(1, sheet.nrows):
            row = []
            empty = True
            for c, _header in enumerate(headers):
                text = _cell_text(sheet, book, r, c, cache, xlrd)
                if text and text != "null":
                    empty = False
                row.append(text)
            if not empty:
                writer.writerow(row)

        sys.stdout.buffer.write(buf.getvalue().encode("utf-8-sig"))
        return 0
    except Exception as exc:  # pylint: disable=broad-except
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
