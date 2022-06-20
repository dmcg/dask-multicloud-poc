from pygments import highlight
from pygments.lexers import PythonLexer
from pygments.lexers import BashLexer
from pygments.formatters import HtmlFormatter
import IPython


def render_py(file): 
    return render(file, PythonLexer())


def render_sh(file): 
    return render(file, BashLexer())


def render(file, lexer):
    with open(file) as f:
        code = f.read()

        formatter = HtmlFormatter()
        return '<style type="text/css">{}</style>{}'.format(
            formatter.get_style_defs('.highlight'),
            highlight(code, lexer, formatter))
        
