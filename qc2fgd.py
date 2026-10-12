from datetime import datetime
from pathlib import Path
import argparse

# TODO: put all the baseclasses first

def get_fgd_defs(qc):
    return [p.split('*/', 1)[0].strip()  + '\n' for p in qc.split('/*FGD')[1:]]

def get_qcs(progs_file: Path):
    # load every file listed in progs.src except the header
    return [qc_file
            for line in progs_file.read_text().splitlines()[1:]
            if (qc_file := line.split('//', 1)[0].strip()) and not line.startswith('#')
            ]

def main():
    parser = argparse.ArgumentParser()

    parser.add_argument('name', nargs='?', type=str, metavar='FGD name', help='Name of FGD file')
    parser.add_argument('-i', '--input', type=Path, metavar='DIR', help='Project directory', default=Path(__file__).parent)
    parser.add_argument('-o', '--output', type=Path, metavar='DIR', help='Output directory')

    args = parser.parse_args()
    fgd_dir = args.output or args.input / 'exports'
    fgd_name = args.name or args.input.name.lower()
    fgd_file = (fgd_dir / fgd_name).with_suffix('.fgd')

    header = f'''// Copper Quake game definition file (.fgd)
// for Worldcraft 1.6 and above

// If something is wrong with this file, check
//   >  http://lunaran.com/files/copper.fgd  <
// for the very latest version before anything else

// Based heavily on quake.fgd by autolycus/czg/et al
// Generated from Copper QuakeC source comments on {datetime.now().strftime('%m.%d.%Y')}\n'''
    def_out = [header]

    # TODO: open quakeC in progs.src order for better fgd order control
    print('Scanning *.qc for FGD comments...')
    for qc_file in get_qcs(args.input / 'progs.src'):
        if defs := get_fgd_defs(Path(qc_file).read_text()):
            def_out.extend([f'\n//\n// {qc_file}\n//\n'] + defs + ['\n'])

    print(f'Exporting to {fgd_file}')
    fgd_file.write_text(''.join(def_out))
    print(f'Exported {sum(s.count('@') for s in def_out)} defs')

if __name__ == '__main__':
    main()
