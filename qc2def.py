from pathlib import Path
import sys

# GtkRadiant doesn't add skill flags by default, and I'd rather keep the source
# clean by adding them here instead, because what else is python for?
def add_skill_flags(def_txt):
    def_lines = def_txt.splitlines()
    init_bits = def_lines[0].split()

    cname = init_bits[1]
    if cname in ('func_group', 'worldspawn', 'misc_external_map') or cname.startswith('func_detail'):
        return def_txt

    # init_bits[5][0] == '(' - point ent
    # otherwise brush ent
    size = (19 if init_bits[5][0] == '(' else 14) - len(init_bits)
    init_bits.extend(['?'] * size + ['NotEasy', 'NotNormal', 'NotHard', 'NotDeathmatch', 'CoopOnly', 'NotCoop'])
    if cname.startswith('monster') or 'alt target' in def_txt.lower():
        init_bits.append('AltTarget')

    def_lines[0] = ' '.join(init_bits)
    return '\n'.join(def_lines).expandtabs(4)

def get_quake_defs(qc):
    def_out = ['\n' + add_skill_flags('/*QUAKED' + p.split('*/', 1)[0] + '*/') + '\n' for p in qc.split('/*QUAKED')[1:]]
    return def_out

def main():
    qcs_dir = Path(__file__).parent
    def_dir = Path('exports')
    def_name = (Path(sys.argv[1]) if len(sys.argv) > 1 else qcs_dir).with_suffix('.def').name.lower()

    print('Scanning *.qc for def comments...')
    def_out = []
    num_defs = 0

    # Not using progs.src order here?
    for qc_file in qcs_dir.glob('*.qc'):
        defs = get_quake_defs(qc_file.read_text())
        def_out.extend(defs)
        num_defs += len(defs)

    def_file = def_dir / def_name
    print(f'Exporting to {def_file}')
    # Use '\n'.join() here instead of in the comprehension to avoid empty first line?
    def_file.write_text(''.join(def_out))
    print(f'Exported {num_defs} defs')

if __name__ == '__main__':
    main()
