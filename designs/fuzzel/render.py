from pathlib import Path
import base64
import html
import subprocess

OUT = Path(__file__).parent
APPS = [('kitty', 'kitty'), ('Google Chrome', 'google-chrome'), ('Spotify', 'spotify'), ('1Password', '1password'), ('Discord', 'discord'), ('Files', 'org.gnome.Nautilus')]
SEARCH = [('Google Chrome', 'google-chrome'), ('Google Chrome Beta', 'google-chrome-beta')]

def rect(x, y, w, h, color, radius=0, stroke='none'):
  return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{color}" stroke="{stroke}"/>'

def text(x, y, value, color, size=16):
  return f'<text x="{x}" y="{y}" fill="{color}" font-family="Hack Nerd Font Mono" font-size="{size}">{html.escape(value)}</text>'

def icon(x, y, name):
  data = base64.b64encode(Path(f'/usr/share/icons/Papirus/32x32/apps/{name}.svg').read_bytes()).decode()
  return f'<image x="{x}" y="{y}" width="24" height="24" href="data:image/svg+xml;base64,{data}"/>'

def panel(x, y, p, search=False):
  w, pad, row = p['width'], p['pad'], p['row']
  h = pad * 2 + row * 7 + p['gap']
  s = rect(x, y, w, h, p['bg'], p['radius'], p['border'])
  tx = x + pad
  baseline = y + pad + row / 2 + 6
  s += text(tx, baseline, '›', p['accent'], 20)
  s += text(tx + 28, baseline, 'chr' if search else 'Search applications…', p['fg'] if search else p['muted'])
  if search:
    s += rect(tx + 59, baseline - 15, 2, 19, p['accent'])
  top = y + pad + row + p['gap']
  for i, (name, image) in enumerate(SEARCH if search else APPS):
    ry = top + i * row
    if i == 0:
      s += rect(tx - 8, ry, w - pad * 2 + 16, row, p['selected'], p['selection_radius'])
    offset = 0
    if p['icons']:
      s += icon(tx, ry + (row - 24) / 2, image)
      offset = 38
    s += text(tx + offset, ry + row / 2 + 6, name, p['fg'] if i == 0 else p['text'])
    if search:
      s += text(tx + offset + 7 * 9.64, ry + row / 2 + 6, 'Chr', p['selected_match'] if i == 0 else p['accent'])
  return s

variants = [
  dict(slug='01-slate', name='01 / Slate', tag='The closest match to your Quickshell panels', note='Papirus icons · 42px rows · restrained blue selection', bg='#171A20', fg='#F8F9FB', text='#B7BEC9', muted='#8D96A5', accent='#8CAED8', selected='#3E5978', selected_match='#C9E1F7', border='#33404D', width=500, pad=26, row=42, gap=14, radius=26, selection_radius=10, icons=True),
  dict(slug='02-graphite', name='02 / Graphite', tag='A quieter, tighter keyboard-first launcher', note='Text only · 34px rows · neutral selection with blue matches', bg='#20242C', fg='#F8F9FB', text='#B7BEC9', muted='#8D96A5', accent='#8CAED8', selected='#2B303A', selected_match='#8CAED8', border='#33404D', width=460, pad=20, row=34, gap=12, radius=20, selection_radius=8, icons=False),
  dict(slug='03-porcelain', name='03 / Porcelain', tag='The light-theme counterpart to your shell', note='Papirus icons · 42px rows · pale blue selection', bg='#F8F9FB', fg='#20242A', text='#59616D', muted='#7B8491', accent='#477AA8', selected='#C9E1F7', selected_match='#365F84', border='#D7DCE3', width=500, pad=26, row=42, gap=14, radius=26, selection_radius=10, icons=True),
]

for p in variants:
  s = '<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="860" viewBox="0 0 1400 860">'
  s += rect(0, 0, 1400, 860, '#101318')
  s += text(66, 76, p['name'], '#F8F9FB', 30)
  s += text(66, 112, p['tag'], '#B7BEC9')
  s += text(66, 159, p['note'], '#8D96A5', 13)
  for x, label, search in [(66, 'OPEN / FREQUENT APPLICATIONS', False), (730, 'FILTERED / “chr”', True)]:
    s += text(x, 227, label, '#8CAED8', 12)
    s += rect(x, 250, 604, 478, '#15191F', 14)
    height = p['pad'] * 2 + p['row'] * 7 + p['gap']
    s += panel(x + (604 - p['width']) / 2, 250 + (478 - height) / 2, p, search)
  s += text(66, 780, 'Hack Nerd Font Mono  /  Native Fuzzel controls  /  Fixed-height results', '#B7BEC9', 13)
  s += text(66, 812, 'Design mockup · Example app ordering · Flat surfaces, no blur or animation required', '#76808D', 12)
  s += '</svg>'
  svg = OUT / (p['slug'] + '.svg')
  svg.write_text(s)
  subprocess.run(['rsvg-convert', str(svg), '-o', str(OUT / (p['slug'] + '.png'))], check=True)
  print(OUT / (p['slug'] + '.png'))
