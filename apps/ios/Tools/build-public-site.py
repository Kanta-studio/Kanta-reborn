"""Render the two reviewed public Markdown documents without external packages."""
from html import escape
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'PublicSite'

def inline(text):
    text = escape(text)
    text = re.sub(r'\[([^\]]+)\]\((https://[^\s)]+)\)', r'<a href="\2">\1</a>', text)
    text = re.sub(r'(?<!["=])(https://kanta-public\.vercel\.app/(?:privacy|support))(?![\w/])', r'<a href="\1">\1</a>', text) if '<a ' not in text else text
    return re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', text)

def markdown(text):
    result=[]
    for block in text.strip().split('\n\n'):
        if block.startswith('# '): result.append('<h1>'+inline(block[2:])+'</h1>')
        elif block.startswith('## '): result.append('<h2>'+inline(block[3:])+'</h2>')
        elif block.startswith('- '): result.append('<ul>'+''.join('<li>'+inline(line[2:])+'</li>' for line in block.splitlines())+'</ul>')
        else: result.append('<p>'+inline(' '.join(block.splitlines()))+'</p>')
    return '\n'.join(result)

def page(title, body):
    return f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="description" content="KANTA offline karaoke — privacy and support"><title>{escape(title)} · KANTA</title><link rel="stylesheet" href="/style.css"></head>
<body><a class="skip" href="#content">Skip to content</a><header><a class="brand" href="/">KANTA</a><nav aria-label="Main"><a href="/support">Support</a><a href="/privacy">Privacy</a></nav></header><main id="content">{body}</main><footer>Your music. Your stage. · iPhone &amp; iPad</footer></body></html>'''

if __name__=='__main__':
    OUTPUT.mkdir(exist_ok=True)
    for name,title in [('PRIVACY','Privacy Policy'),('SUPPORT','Support')]:
        (OUTPUT/(name.lower()+'.html')).write_text(page(title,markdown((ROOT/(name+'.md')).read_text())))
    (OUTPUT/'index.html').write_text(page('Your music. Your stage.', '<p class="eyebrow">OFFLINE KARAOKE</p><h1>Your music.<br>Your stage.</h1><p>KANTA brings your own karaoke library to iPhone and iPad, with local playback, synchronized lyrics, and optional on-device scoring.</p><p>Currently preparing for internal TestFlight testing. Public distribution is not available yet.</p><p><a class="button" href="/support">Library help &amp; beta support</a></p><p><a href="/privacy">Read the privacy policy</a></p>'))
