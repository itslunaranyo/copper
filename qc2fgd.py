from datetime import datetime
from pathlib import Path
import sys

# TODO: put all the baseclasses first

def get_fgd_defs(qc):
    return [p.split('*/', 1)[0].strip()  + '\n' for p in qc.split('/*FGD')[1:]]

def get_qcs(qcs_dir: Path):
    # load every file listed in progs.src except the header
    return [qc_file
            for line in (qcs_dir / 'progs.src').read_text().splitlines()[1:]
            if (qc_file := line.split('//', 1)[0].strip()) and not line.startswith('#')
            ]

def main():
    qcs_dir = Path(__file__).parent
    fgd_dir = qcs_dir / 'exports'
    fgd_file = fgd_dir / (Path(sys.argv[1]) if len(sys.argv) > 1 else qcs_dir).with_suffix('.fgd').name.lower()

    print('Scanning *.qc for FGD comments...')
    header = f'''// Copper Quake game definition file (.fgd)
// for Worldcraft 1.6 and above

// If something is wrong with this file, check
//   >  http://lunaran.com/files/copper.fgd  <
// for the very latest version before anything else

// Based heavily on quake.fgd by autolycus/czg/et al
// Generated from Copper QuakeC source comments on {datetime.now().strftime('%m.%d.%Y')}\n'''
    def_out = [header]

    # TODO: open quakeC in progs.src order for better fgd order control
    for qc_file in get_qcs(qcs_dir):
        if defs := get_fgd_defs(Path(qc_file).read_text()):
            def_out.extend([f'\n//\n// {qc_file}\n//\n'] + defs + ['\n'])

    print(f'Exporting to {fgd_file}')
    fgd_file.write_text(''.join(def_out))
    print(f'Exported {sum(s.count('@') for s in def_out)} defs')

if __name__ == '__main__':
    main()
