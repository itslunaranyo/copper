from datetime import datetime
from pathlib import Path
import sys

# TODO: put all the baseclasses first

def get_fgd_defs(qc):
    def_out = [p.split('*/', 1)[0].strip() + '\n' for p in qc.split('/*FGD')[1:]]
    return def_out

def get_qcs():
    # load every file listed in progs.src except the header
    prog_lines = Path('progs.src').read_text().splitlines()[1:]
    return [qc_file
            for line in prog_lines
            if (qc_file := line.split('//', 1)[0].strip()) and not line.startswith('#')
            ]

def main():
    qcs_dir = Path(__file__).parent
    fgd_dir = Path('exports')
    fgd_name = (Path(sys.argv[1]) if len(sys.argv) > 1 else qcs_dir).with_suffix('.fgd').name.lower()

    print('Scanning *.qc for FGD comments...')
    header = f'''// Copper Quake game definition file (.fgd)
// for Worldcraft 1.6 and above

// If something is wrong with this file, check
//   >  http://lunaran.com/files/copper.fgd  <
// for the very latest version before anything else

// Based heavily on quake.fgd by autolycus/czg/et al
// Generated from Copper QuakeC source comments on {datetime.now().strftime('%m.%d.%Y')}\n'''
    def_out = []
    num_defs = 0

    # TODO: open quakeC in progs.src order for better fgd order control
    for qc_file in get_qcs():
        defs = get_fgd_defs(Path(qc_file).read_text())
        if not defs:
            continue
        # Use '\n'.join() here instead of in get_fgd_defs() to avoid double new lines?
        def_out.append(f'\n//\n// {qc_file}\n//\n{''.join(defs)}\n')
        num_defs += len(defs)
    def_out.insert(0, header)

    fgd_file = fgd_dir / fgd_name
    print(f'Exporting to {fgd_file}')
    fgd_file.write_text(''.join(def_out))
    print(f'Exported {num_defs} defs')

if __name__ == '__main__':
    main()
